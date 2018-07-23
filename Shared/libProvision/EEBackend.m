//
//  EEBackend.m
//  OpenExtenderTest
//
//  Created by Matt Clarke on 02/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "EEBackend.h"
#import "EEProvisioning.h"
#import "EESigning.h"
#import "EEAppleServices.h"
#import "SSZipArchive.h"

@implementation EEBackend

+ (void)provisionDevice:(NSString*)udid name:(NSString*)name username:(NSString*)username password:(NSString*)password priorChosenTeamID:(NSString*)teamId withCallback:(void (^)(NSError *))completionHandler {
    
    EEProvisioning *provisioner = [EEProvisioning provisionerWithCredentials:username :password];
    [provisioner provisionDevice:udid name:name withTeamIDCheck:^ NSString* (NSArray* teams) {
        
        // If this is called, then the user is on multiple teams, and must be asked which one they want to use.
        // When integrated into an app, this backend can assume that this choice has been prior made, and so
        // we can return the result of that choice now.
        
        return teamId;
        
    } andCallback:^(NSError *error) {
        completionHandler(error);
    }];
}

+ (void)revokeDevelopmentCertificatesForCurrentMachineWithUsername:(NSString*)username password:(NSString*)password priorChosenTeamID:(NSString*)teamId withCallback:(void (^)(NSError *))completionHandler {
    
    EEProvisioning *provisioner = [EEProvisioning provisionerWithCredentials:username :password];
    [provisioner revokeCertificatesWithTeamIDCheck:^ NSString* (NSArray* teams) {
        
        // If this is called, then the user is on multiple teams, and must be asked which one they want to use.
        // When integrated into an app, this backend can assume that this choice has been prior made, and so
        // we can return the result of that choice now.
        
        return teamId;
        
    } andCallback:^(NSError *error) {
        completionHandler(error);
    }];
}

+ (void)signBundleAtPath:(NSString*)path username:(NSString*)username password:(NSString*)password priorChosenTeamID:(NSString*)teamId withCompletionHandler:(void (^)(NSError *))completionHandler {
    
    // 1. Read Info.plist to gain the applicationId and binaryLocation.
    // 2. Get provisioning profile and certificate info
    // 3. Sign bundle
    
    NSDictionary *infoplist = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Info.plist", path]];
    
    if (!infoplist || [infoplist allKeys].count == 0) {
        NSError *error = [self _errorFromString:@"Failed to open Info.plist!"];
        completionHandler(error);
        return;
    }
    
    NSString *applicationId = [infoplist objectForKey:@"CFBundleIdentifier"];
    NSString *binaryLocation = [path stringByAppendingFormat:@"/%@", [infoplist objectForKey:@"CFBundleExecutable"]];
    
    // We get entitlements from the binary using ldid::Analyze() during provisioning, updating them as needed
    // for the current Team ID.
    
    EEProvisioning *provisioner = [EEProvisioning provisionerWithCredentials:username :password];
    [provisioner downloadProvisioningProfileForApplicationIdentifier:applicationId binaryLocation:(NSString*)binaryLocation withTeamIDCheck:^ NSString* (NSArray* teams) {
        
        // If this is called, then the user is on multiple teams, and must be asked which one they want to use.
        // When integrated into an app, this backend can assume that this choice has been prior made, and so
        // we can return the result of that choice now.
        
        return teamId;
        
    } andCallback:^(NSError *error, NSData *embeddedMobileProvision, NSString *privateKey, NSDictionary *certificate, NSDictionary *entitlements) {
        if (error) {
            completionHandler(error);
            return;
        }
        
        // We now have a valid provisioning profile for this application!
        // And, we also have a valid development codesigning certificate, with its private key!
        
        // Add embedded.mobileprovision to the bundle, overwriting if needed.
        NSError *fileIOError;
        NSString *embeddedPath = [NSString stringWithFormat:@"%@/embedded.mobileprovision", path];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:embeddedPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:embeddedPath error:&fileIOError];
            
            if (fileIOError) {
                NSLog(@"%@", fileIOError);
                return;
            }
        }
        
        if (![(NSData*)embeddedMobileProvision writeToFile:embeddedPath options:NSDataWritingAtomic error:&fileIOError]) {
            
            if (fileIOError) {
                NSLog(@"%@", fileIOError);
            } else {
                NSLog(@"Failed to write '%@'.", embeddedPath);
            }
            
            return;
        }
        
        // Next step: signing. To do this, we use EESigner with these four results.
        EESigning *signer = [EESigning signerWithCertificate:certificate[@"certContent"] privateKey:privateKey];
        [signer signBundleAtPath:path entitlements:entitlements withCallback:^(BOOL success, NSString *result) {
           
            // Return to the caller on a new thread.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                // We will now pause so that ldid can cleanup after itself.
                [NSThread sleepForTimeInterval:1];
                
                NSError *error = nil;
                if (!success) {
                    error = [self _errorFromString:result];
                }
                
                // We're done.
                completionHandler(error);
            });
        }];
    }];
}

+ (void)signIpaAtPath:(NSString*)ipaPath outputPath:(NSString*)outputPath username:(NSString*)username password:(NSString*)password priorChosenTeamID:(NSString*)teamId withCompletionHandler:(void (^)(NSError *))completionHandler {
    
    // 1. Unpack IPA to a temporary directory.
    NSError *error;
    NSString *unpackedDirectory;
    if (![self unpackIpaAtPath:ipaPath outDirectory:&unpackedDirectory error:&error]) {
        completionHandler(error);
        return;
    }
    
    // 2. Sign its main bundle via above method.
    // The bundle will be located at <temporarydirectory>/<zipfilename>/Payload/*.app internally
    
    NSString *zipFilename = [ipaPath lastPathComponent];
    zipFilename = [zipFilename stringByReplacingOccurrencesOfString:@".ipa" withString:@""];
    
    NSString *payloadDirectory = [NSString stringWithFormat:@"%@/Payload", unpackedDirectory];
    
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadDirectory error:&error];
    
    if (error) {
        completionHandler(error);
        return;
    } else if (files.count == 0) {
        NSError *err = [self _errorFromString:@"Payload directory of IPA has no contents"];
        completionHandler(err);
        return;
    }
    
    NSString *dotAppDirectory = @"";
    for (NSString *directory in files) {
        if ([directory containsString:@".app"]) {
            dotAppDirectory = directory;
            break;
        }
    }
    
    NSString *bundleDirectory = [NSString stringWithFormat:@"%@/%@", payloadDirectory, dotAppDirectory];
    
    NSLog(@"Signing bundle at path '%@'", bundleDirectory);
    
    [self signBundleAtPath:bundleDirectory username:username password:password priorChosenTeamID:teamId withCompletionHandler:^(NSError *err) {
        if (err) {
            completionHandler(err);
            return;
        }
        
        // 3. Repack IPA to output path
        NSError *error2;
        if (![self repackIpaAtPath:[NSString stringWithFormat:@"%@/%@", [self applicationTemporaryDirectory], zipFilename] toPath:outputPath error:&error2]) {
            completionHandler(error2);
        } else {
            // Success!
            completionHandler(nil);
        }
    }];
}

+ (BOOL)unpackIpaAtPath:(NSString*)ipaPath outDirectory:(NSString**)outputDirectory error:(NSError**)error {
    
    // Sanity checks.
    if (![ipaPath hasSuffix:@".ipa"]) {
        if (error)
            *error = [self _errorFromString:@"Input file specified is not an IPA!"];
        return NO;
    }

    if (!outputDirectory) {
        if (error)
            *error = [self _errorFromString:@"No outputDirectory; how will you know where the IPA was extracted to?"];
        return NO;
    }
    
    NSString *zipFilename = [ipaPath lastPathComponent];
    zipFilename = [zipFilename stringByReplacingOccurrencesOfString:@".ipa" withString:@""];
    
    *outputDirectory = [NSString stringWithFormat:@"%@/%@", [self applicationTemporaryDirectory], zipFilename];
    
    NSLog(@"Unpacking '%@' into directory '%@'", ipaPath, *outputDirectory);
    
    if (![SSZipArchive unzipFileAtPath:ipaPath toDestination:*outputDirectory]) {
        if (error)
            *error = [self _errorFromString:@"Failed to unpack IPA!"];
        return NO;
    }
    
    return YES;
}

+ (BOOL)repackIpaAtPath:(NSString*)extractedPath toPath:(NSString*)outputPath error:(NSError**)error {
    
    // Sanity checks.
    if (![outputPath hasSuffix:@".ipa"]) {
        if (error)
            *error = [self _errorFromString:@"Output file specified is not an IPA!"];
        return NO;
    }
    
    NSLog(@"Creating IPA from contents of '%@", extractedPath);
    
    // Ensure permissions are at least read on everyone.
    
    
    if (![SSZipArchive createZipFileAtPath:outputPath withContentsOfDirectory:extractedPath]) {
        if (error)
            *error = [self _errorFromString:@"Failed to repack IPA!"];
        return NO;
    }
    
    return YES;
}

+ (NSString*)applicationTemporaryDirectory {
    NSString * tempDir = NSTemporaryDirectory();
    if (!tempDir)
        tempDir = @"/tmp";
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:tempDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:NO attributes:nil error:nil];
    }
    
    return tempDir;
}

+ (NSError*)_errorFromString:(NSString*)string {
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: NSLocalizedString(string, nil),
                               NSLocalizedFailureReasonErrorKey: NSLocalizedString(string, nil),
                               NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                               };
    
    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:-1
                                     userInfo:userInfo];
    
    return error;
}

@end
