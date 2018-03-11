//
//  RPVApplicationSigning.m
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVApplicationSigning.h"
#import "RPVApplicationDatabase.h"
#import "RPVApplication.h"
#import "EEBackend.h"

/* Private headers */
@interface LSApplicationWorkspace : NSObject
+(instancetype)defaultWorkspace;
-(BOOL)installApplication:(NSURL*)arg1 withOptions:(NSDictionary*)arg2 error:(NSError**)arg3;
- (NSArray*)allApplications;
@end


@interface RPVApplicationSigning ()

@property (nonatomic, strong) NSMutableArray *installQueue;
@property (nonatomic, readwrite) BOOL undertakingResignPipeline;

@end

static RPVApplicationSigning *sharedInstance;

@implementation RPVApplicationSigning

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

- (void)resignApplications:(BOOL)onlyExpiringApplications thresholdForExpiration:(int)thresholdForExpiration withTeamID:(NSString*)teamID username:(NSString*)username password:(NSString*)password progressUpdateHandler:(void (^)(NSString*, int))progressUpdateHandler errorHandler:(void (^)(NSError*, NSString*))errorHandler andCompletionHandler:(void (^)(NSError*))completionHandler {
    
    if (self.undertakingResignPipeline) {
        NSError *error = [self _errorFromString:@"Already undertaking the re-sign pipeline!" errorCode:RPVErrorAlreadyUndertakingPipeline];
        completionHandler(error);
        return;
    } else {
        self.undertakingResignPipeline = YES;
    }
    
    //////////////////////////////////////////////////////////////////////////////////////
    // 1. Do pre-flight checks.
    //////////////////////////////////////////////////////////////////////////////////////
    
    // TODO: Network connectivity.
    
    //////////////////////////////////////////////////////////////////////////////////////
    // 2. Iterate over all the applications available in RPVApplicationDatabase.
    //////////////////////////////////////////////////////////////////////////////////////
    
    // Get list of applications from RPVApplicationDatabase
    NSMutableArray *applications;
    if (onlyExpiringApplications) {
        
        NSDate *now = [NSDate date];
        NSDate *expirationDate = [now dateByAddingTimeInterval:60 * 60 * 24 * thresholdForExpiration];
        
        [[RPVApplicationDatabase sharedInstance] getApplicationsWithExpiryDateBefore:&applications andAfter:nil date:expirationDate forTeamID:teamID];
        
    } else {
        
        applications = [[[RPVApplicationDatabase sharedInstance] getAllApplicationsForTeamID:teamID] mutableCopy];
    }
    
    // Update install queue with new applications list
    self.installQueue = applications;
    
    //////////////////////////////////////////////////////////////////////////////////////
    // 3. Initiate signing for applications if applicable.
    //////////////////////////////////////////////////////////////////////////////////////
    
    // If no signing needed, just exit.
    if (self.installQueue.count == 0) {
        self.undertakingResignPipeline = NO;
        NSError *error = [self _errorFromString:@"No applications need re-signing" errorCode:RPVErrorNoSigningRequired];
        completionHandler(error);
        return;
    }
    
    // Update progress handler to 0% for all applications.
    for (RPVApplication *app in self.installQueue) {
        progressUpdateHandler(app.bundleIdentifier, 0);
    }
    
    // Start signing.
    [self _initiateNextInstallFromQueueWithTeamID:teamID
                                         username:username
                                           password:password
                              progressUpdateHandler:progressUpdateHandler
                                       errorHandler:errorHandler
                               andCompletionHandler:completionHandler];
}

/**
 For the given RPVApplication, this method copies its .app bundle into a directory structure of
 an extracted IPA, in a temporary directory.
 
 @param extractedArchiveURL Output URL of where the root directory structure is located
 @param applicationBundleURL Output URL of where the application's bundle is located
 @param error If non-null, any arising error.
 @return Success
 */
- (BOOL)_copyApplicationBundleForApplication:(RPVApplication*)application extractedArchiveURL:(NSURL**)extractedArchiveURL applicationBundleURL:(NSURL**)applicationBundleURL error:(NSError**)error {
    NSString *temporaryDirectory = [EEBackend applicationTemporaryDirectory];
    
    NSString *applicationBundleLocation = [application locationOfApplicationOnFilesystem].path;
    NSString *dotAppName = [applicationBundleLocation lastPathComponent];
    
    NSString *toPath = [NSString stringWithFormat:@"%@/%@/Payload/%@", temporaryDirectory, [application bundleIdentifier], dotAppName];
    
    // Create the parent path if needed
    NSString *parentPath = [toPath stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:parentPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:parentPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSError *err;
    if (![[NSFileManager defaultManager] copyItemAtPath:applicationBundleLocation toPath:toPath error:&err]) {
        if (error) {
            *error = [self _errorFromString:err.localizedDescription errorCode:RPVErrorFailedToCopyBundle];
        }
        return NO;
    }
    
    *extractedArchiveURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", temporaryDirectory, [application bundleIdentifier]]];
    *applicationBundleURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@/Payload/%@", temporaryDirectory, [application bundleIdentifier], dotAppName]];
    
    return YES;
}

- (NSError*)_errorFromString:(NSString*)string errorCode:(int)code {
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: NSLocalizedString(string, nil),
                               NSLocalizedFailureReasonErrorKey: NSLocalizedString(string, nil),
                               NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                               };
    
    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:code
                                     userInfo:userInfo];
    
    return error;
}

- (void)_initiateNextInstallFromQueueWithTeamID:(NSString*)teamID username:(NSString*)username password:(NSString*)password progressUpdateHandler:(void (^)(NSString*, int))progressUpdateHandler errorHandler:(void (^)(NSError*, NSString*))errorHandler andCompletionHandler:(void (^)(NSError*))completionHandler {
    
    if ([self.installQueue count] == 0) {
        // We can exit now.
        self.undertakingResignPipeline = NO;
        completionHandler(nil);
    } else {
        // Pull next off the front of the array.
        RPVApplication *application = [self.installQueue firstObject];
        
        [self _resignApplication:application
                      withTeamID:teamID
                        username:username
                        password:password
           progressUpdateHandler:progressUpdateHandler
                    errorHandler:errorHandler
            andCompletionHandler:completionHandler];
    }
}

- (void)_installIpaAtPath:(NSString*)ipaPath withBundleIdentifier:(NSString*)bundleIdentifier progressUpdateHandler:(void (^)(NSString*, int))progressUpdateHandler errorHandler:(void (^)(NSError*, NSString*))errorHandler {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSDictionary *options = @{@"CFBundleIdentifier" : bundleIdentifier, @"AllowInstallLocalProvisioned" : [NSNumber numberWithBool:YES]};
        
        NSURL *ipaURL = [NSURL fileURLWithPath:ipaPath];
        
        BOOL result = [[LSApplicationWorkspace defaultWorkspace] installApplication:ipaURL
                                                                        withOptions:options
                                                                              error:&error];
        // Update progress to 90% for this application.
        progressUpdateHandler(bundleIdentifier, 90);
        
        if (!result) {
            // Give an error!
            NSError *err = [self _errorFromString:error.localizedDescription errorCode:RPVErrorFailedToInstallSignedIPA];
            errorHandler(err, bundleIdentifier);
        }
        
        // Clean up.
        [[NSFileManager defaultManager] removeItemAtPath:ipaPath error:nil];
        
        // Update progress to 100% for this application.
        progressUpdateHandler(bundleIdentifier, 100);
        
        // TODO: if this was the last application, notify the completionHandler of success
    });
}

- (void)_resignApplication:(RPVApplication*)application withTeamID:(NSString*)teamID username:(NSString*)username password:(NSString*)password progressUpdateHandler:(void (^)(NSString*, int))progressUpdateHandler errorHandler:(void (^)(NSError*, NSString*))errorHandler andCompletionHandler:(void (^)(NSError*))completionHandler {
    
    // Update progress to 10% for this application.
    progressUpdateHandler([application bundleIdentifier], 10);
    
    //////////////////////////////////////////////////////////////////////////////////////
    // 1. Make a copy of this application's .app into a directory structure of an IPA.
    //////////////////////////////////////////////////////////////////////////////////////
    
    NSURL *extractedArchiveURL; // This root directory is repacked into an IPA.
    NSURL *applicationBundleURL; // Passed to EEbackend to sign (the .app).
    NSError *error;
    
    if (![self _copyApplicationBundleForApplication:application extractedArchiveURL:&extractedArchiveURL applicationBundleURL:&applicationBundleURL error:&error]) {
        
        // Callback to say we done "goofed".
        errorHandler(error, [application bundleIdentifier]);
        
        // Start the next application off.
        if (self.installQueue.count > 0) {
            [self.installQueue removeObjectAtIndex:0];
            [self _initiateNextInstallFromQueueWithTeamID:teamID
                                                 username:username
                                                 password:password
                                    progressUpdateHandler:progressUpdateHandler
                                             errorHandler:errorHandler
                                     andCompletionHandler:completionHandler];
        } else {
            completionHandler(error);
        }
        
        return;
    }
    
    // Update progress to 30% for this application.
    progressUpdateHandler([application bundleIdentifier], 30);
    
    //////////////////////////////////////////////////////////////////////////////////////
    // 2. Use libProvision to sign the .app
    //////////////////////////////////////////////////////////////////////////////////////
    
    [EEBackend signBundleAtPath:[applicationBundleURL path] username:username password:password priorChosenTeamID:teamID withCompletionHandler:^(NSError *error) {
        if (error) {
            // Callback to say we done "goofed".
            errorHandler(error, [application bundleIdentifier]);
            
            // TODO: Cleanup the filesystem?
            
            // Start the next application off.
            if (self.installQueue.count > 0) {
                [self.installQueue removeObjectAtIndex:0];
                [self _initiateNextInstallFromQueueWithTeamID:teamID
                                                     username:username
                                                     password:password
                                        progressUpdateHandler:progressUpdateHandler
                                                 errorHandler:errorHandler
                                         andCompletionHandler:completionHandler];
            } else {
                completionHandler(error);
            }
            
            return;
        }
        
        // Update progress to 50% for this application.
        progressUpdateHandler([application bundleIdentifier], 50);
        
        //////////////////////////////////////////////////////////////////////////////////////
        // 3. Build IPA
        //////////////////////////////////////////////////////////////////////////////////////
        
        NSString *outputIpaPath = [NSString stringWithFormat:@"%@/%@.ipa", [EEBackend applicationTemporaryDirectory], [application bundleIdentifier]];
        
        NSError *err;
        if (![EEBackend repackIpaAtPath:[extractedArchiveURL path] toPath:outputIpaPath error:&err]) {
            
            // Callback to say we done "goofed".
            errorHandler(err, [application bundleIdentifier]);
            
            // TODO: Cleanup the filesystem?
            
            // Start the next application off.
            if (self.installQueue.count > 0) {
                [self.installQueue removeObjectAtIndex:0];
                [self _initiateNextInstallFromQueueWithTeamID:teamID
                                                 username:username
                                                 password:password
                                    progressUpdateHandler:progressUpdateHandler
                                             errorHandler:errorHandler
                                     andCompletionHandler:completionHandler];
            } else {
                completionHandler(err);
            }
            
            return;
        }
        
        // Update progress to 60% for this application.
        progressUpdateHandler([application bundleIdentifier], 60);
        
        //////////////////////////////////////////////////////////////////////////////////////
        // 4. Install IPA
        //////////////////////////////////////////////////////////////////////////////////////
        
        NSString *bundleIdentifier = [application bundleIdentifier];
        
        // Start the next application off at this point for some parallelism!
        if (self.installQueue.count > 0) {
            [self.installQueue removeObjectAtIndex:0];
            [self _initiateNextInstallFromQueueWithTeamID:teamID
                                             username:username
                                             password:password
                                progressUpdateHandler:progressUpdateHandler
                                         errorHandler:errorHandler
                                 andCompletionHandler:completionHandler];
        }
        
        // And now we install!
        [self _installIpaAtPath:outputIpaPath withBundleIdentifier:bundleIdentifier progressUpdateHandler:progressUpdateHandler errorHandler:errorHandler];
    }];
}

@end
