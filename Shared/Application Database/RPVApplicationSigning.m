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

#import "SSZipArchive.h"

/* Private headers */
@interface LSApplicationWorkspace : NSObject
+(instancetype)defaultWorkspace;
-(BOOL)installApplication:(NSURL*)arg1 withOptions:(NSDictionary*)arg2 error:(NSError**)arg3;
- (NSArray*)allApplications;
- (BOOL)uninstallApplication:(id)arg1 withOptions:(id)arg2;
@end


@interface RPVApplicationSigning ()

@property (nonatomic, strong) NSMutableArray *installQueue;
@property (nonatomic, readwrite) BOOL undertakingResignPipeline;
@property (nonatomic, readwrite) UIBackgroundTaskIdentifier currentBackgroundTaskIdentifier;

@property (nonatomic, strong) NSMutableArray *observers;

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

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.observers = [NSMutableArray array];
    }
    
    return self;
}

- (void)addSigningUpdatesObserver:(id<RPVApplicationSigningProtocol>)observer {
    [self.observers addObject:observer];
}

- (void)removeSigningUpdatesObserver:(id<RPVApplicationSigningProtocol>)observer {
    [self.observers removeObject:observer];
}

- (void)_resignApplicationsArray:(NSArray*)applications withTeamID:(NSString*)teamID username:(NSString*)username password:(NSString*)password {
    
    for (id<RPVApplicationSigningProtocol> observer in self.observers) {
        [observer applicationSigningDidStart];
    }
    
    if (self.undertakingResignPipeline) {
        NSError *error = [self _errorFromString:@"Already undertaking the re-sign pipeline!" errorCode:RPVErrorAlreadyUndertakingPipeline];
        
        for (id<RPVApplicationSigningProtocol> observer in self.observers) {
            [observer applicationSigningCompleteWithError:error];
        }
        return;
    } else {
        self.undertakingResignPipeline = YES;
    }
    
    //////////////////////////////////////////////////////////////////////////////////////
    // 1. Do pre-flight checks.
    //////////////////////////////////////////////////////////////////////////////////////
    
    // TODO: Network connectivity.
    
    // Update install queue with new applications list
    self.installQueue = [applications mutableCopy];
    
    //////////////////////////////////////////////////////////////////////////////////////
    // 2. Initiate signing for applications if applicable.
    //////////////////////////////////////////////////////////////////////////////////////
    
    // If no signing needed, just exit.
    if (self.installQueue.count == 0) {
        self.undertakingResignPipeline = NO;
        NSError *error = [self _errorFromString:@"No applications need re-signing" errorCode:RPVErrorNoSigningRequired];
        for (id<RPVApplicationSigningProtocol> observer in self.observers) {
            [observer applicationSigningCompleteWithError:error];
        }
        return;
    }
    
    // Move to a background task!
    UIApplication *application = [UIApplication sharedApplication];
    UIBackgroundTaskIdentifier __block bgTask = [application beginBackgroundTaskWithName:@"ReProvision Application Signing" expirationHandler:^{
        
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    self.currentBackgroundTaskIdentifier = bgTask;
    
    // Update progress handler to 0% for all applications.
    for (RPVApplication *app in self.installQueue) {
        for (id<RPVApplicationSigningProtocol> observer in self.observers) {
            [observer applicationSigningUpdateProgress:0 forBundleIdentifier:app.bundleIdentifier];
        }
    }
    
    // Start signing.
    [self _initiateNextInstallFromQueueWithTeamID:teamID
                                         username:username
                                         password:password];
}

- (void)resignSpecificApplications:(NSArray*)applications withTeamID:(NSString*)teamID username:(NSString*)username password:(NSString*)password {
    
    [self _resignApplicationsArray:applications withTeamID:teamID username:username password:password];
}

- (void)resignApplications:(BOOL)onlyExpiringApplications thresholdForExpiration:(int)thresholdForExpiration withTeamID:(NSString*)teamID username:(NSString*)username password:(NSString*)password {
    //////////////////////////////////////////////////////////////////////////////////////
    // 0. Iterate over all the applications available in RPVApplicationDatabase.
    //////////////////////////////////////////////////////////////////////////////////////
    
    // Get list of applications from RPVApplicationDatabase
    NSMutableArray *applications = [NSMutableArray array];
    if (onlyExpiringApplications) {
        
        NSDate *now = [NSDate date];
        NSDate *expirationDate = [now dateByAddingTimeInterval:60 * 60 * 24 * thresholdForExpiration];
        
        if (![[RPVApplicationDatabase sharedInstance] getApplicationsWithExpiryDateBefore:&applications andAfter:nil date:expirationDate forTeamID:teamID]) {
            // sad times.
            self.undertakingResignPipeline = NO;
            NSError *error = [self _errorFromString:@"Failed to get applications within expiry date" errorCode:-1337];
            for (id<RPVApplicationSigningProtocol> observer in self.observers) {
                [observer applicationSigningCompleteWithError:error];
            }
            return;
        }
    } else {
        applications = [[[RPVApplicationDatabase sharedInstance] getAllApplicationsForTeamID:teamID] mutableCopy];
    }
    
    [self _resignApplicationsArray:applications withTeamID:teamID username:username password:password];
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
    NSString *dotAppName = @"";
    
    if ([application.class isEqual:[RPVApplication class]]) {
        NSString *applicationBundleLocation = [application locationOfApplicationOnFilesystem].path;
        dotAppName = [applicationBundleLocation lastPathComponent];
        
        NSString *toPath = [NSString stringWithFormat:@"%@/%@/Payload/%@", temporaryDirectory, [application bundleIdentifier], dotAppName];
        
        // Create the parent path if needed
        NSString *parentPath = [toPath stringByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:parentPath]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:parentPath withIntermediateDirectories:YES attributes:nil error:nil];
            // Delete any existing .app if needed too.
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:toPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:toPath error:nil];
        }
        
        NSError *err;
        if (![[NSFileManager defaultManager] copyItemAtPath:applicationBundleLocation toPath:toPath error:&err]) {
            if (error) {
                *error = [self _errorFromString:err.localizedDescription errorCode:RPVErrorFailedToCopyBundle];
            }
            return NO;
        }
        
    } else {
        // This is an IPA application, therefore -locationOfApplicationOnFilesystem will return the .ipa
        // file on the filesystem.
        
        // We need to extract the IPA to our temporary location, and roll from there.
        NSString *extractionPath = [NSString stringWithFormat:@"%@/%@", temporaryDirectory, [application bundleIdentifier]];
        NSError *err;
        BOOL success = [SSZipArchive unzipFileAtPath:[application locationOfApplicationOnFilesystem].path
                                       toDestination:extractionPath
                                           overwrite:YES
                                            password:nil
                                               error:&err];
        
        if (success) {
            // Find the .app name
            
            NSArray *subdirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/Payload/", extractionPath] error:nil];
            
            for (NSString *dir in subdirs) {
                if (![dir isEqualToString:@".DS_Store"]) {
                    dotAppName = dir;
                    break;
                }
            }
        } else {
            if (error) {
                *error = [self _errorFromString:err.localizedDescription errorCode:RPVErrorFailedToCopyBundle];
            }
            return NO;
        }
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

- (void)_initiateNextInstallFromQueueWithTeamID:(NSString*)teamID username:(NSString*)username password:(NSString*)password {
    
    if ([self.installQueue count] == 0) {
        // We can exit now.
        self.undertakingResignPipeline = NO;
    } else {
        // Pull next off the front of the array.
        RPVApplication *application = [self.installQueue firstObject];
        
        [self _resignApplication:application
                      withTeamID:teamID
                        username:username
                        password:password];
    }
}

- (void)_installIpaAtPath:(NSString*)ipaPath withBundleIdentifier:(NSString*)bundleIdentifier {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSDictionary *options = @{@"CFBundleIdentifier" : bundleIdentifier, @"AllowInstallLocalProvisioned" : [NSNumber numberWithBool:YES]};
        
        NSURL *ipaURL = [NSURL fileURLWithPath:ipaPath];
        
        // Make a cached version of the .ipa for if we need to handle another go-around.
        [[NSFileManager defaultManager] copyItemAtPath:ipaPath toPath:[ipaPath stringByReplacingOccurrencesOfString:@".ipa" withString:@"2.ipa"] error:nil];
        
        NSLog(@"Does ipaPath exist? %d", [[NSFileManager defaultManager] fileExistsAtPath:ipaPath]);
        
        BOOL result = NO;
        @try {
            result = [[LSApplicationWorkspace defaultWorkspace] installApplication:ipaURL
                                                                       withOptions:options
                                                                             error:&error];
        } @catch (NSException *e) {
            error = [self _errorFromString:e.description errorCode:RPVErrorFailedToInstallSignedIPA];
            result = NO;
        }
        
        if (!result) {
            // Check if this is the case where it's an app from another Team ID.
            if (error.code == 64) {
                // Delete the original app, and try again.
                if ([[LSApplicationWorkspace defaultWorkspace] uninstallApplication:bundleIdentifier withOptions:nil]) {
                    // Try again!
                    
                    // Update progress to 70% for this application.
                    for (id<RPVApplicationSigningProtocol> observer in self.observers) {
                        [observer applicationSigningUpdateProgress:75 forBundleIdentifier:bundleIdentifier];
                    }
                    
                    NSLog(@"*** Uninstalled application, trying again.");
                    [self _installIpaAtPath:[ipaPath stringByReplacingOccurrencesOfString:@".ipa" withString:@"2.ipa"] withBundleIdentifier:bundleIdentifier];
                    
                    return;
                }
            }
            
            // Give an error!
            NSError *err = [self _errorFromString:error.localizedDescription errorCode:RPVErrorFailedToInstallSignedIPA];
            for (id<RPVApplicationSigningProtocol> observer in self.observers) {
                [observer applicationSigningDidEncounterError:err forBundleIdentifier:bundleIdentifier];
            }
        }
        
        if (result) {
            // Update progress to 90% for this application.
            for (id<RPVApplicationSigningProtocol> observer in self.observers) {
                [observer applicationSigningUpdateProgress:90 forBundleIdentifier:bundleIdentifier];
            }
        }
        
        // Clean up.
        [[NSFileManager defaultManager] removeItemAtPath:ipaPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[ipaPath stringByReplacingOccurrencesOfString:@".ipa" withString:@"2.ipa"] error:nil];
        
        if (result) {
            // Update progress to 100% for this application.
            for (id<RPVApplicationSigningProtocol> observer in self.observers) {
                [observer applicationSigningUpdateProgress:100 forBundleIdentifier:bundleIdentifier];
            }
        }
        
        // If this was the last application, notify the completionHandler of success
        if (!self.undertakingResignPipeline) {
            // End the background task!
            [[UIApplication sharedApplication] endBackgroundTask:self.currentBackgroundTaskIdentifier];
            self.currentBackgroundTaskIdentifier = UIBackgroundTaskInvalid;
            
            // Notify of success!
            for (id<RPVApplicationSigningProtocol> observer in self.observers) {
                [observer applicationSigningCompleteWithError:nil];
            }
        }
    });
}

- (void)_resignApplication:(RPVApplication*)application withTeamID:(NSString*)teamID username:(NSString*)username password:(NSString*)password{
    
    // Update progress to 10% for this application.
    for (id<RPVApplicationSigningProtocol> observer in self.observers) {
        [observer applicationSigningUpdateProgress:10 forBundleIdentifier:[application bundleIdentifier]];
    }
    
    //////////////////////////////////////////////////////////////////////////////////////
    // 1. Make a copy of this application's .app into a directory structure of an IPA.
    //////////////////////////////////////////////////////////////////////////////////////
    
    NSURL *extractedArchiveURL; // This root directory is repacked into an IPA.
    NSURL *applicationBundleURL; // Passed to EEbackend to sign (the .app).
    NSError *error;
    
    if (![self _copyApplicationBundleForApplication:application extractedArchiveURL:&extractedArchiveURL applicationBundleURL:&applicationBundleURL error:&error]) {
        
        // Callback to say we done "goofed".
        for (id<RPVApplicationSigningProtocol> observer in self.observers) {
            [observer applicationSigningDidEncounterError:error forBundleIdentifier:[application bundleIdentifier]];
        }
        
        // Start the next application off.
        if (self.installQueue.count > 1) {
            [self.installQueue removeObjectAtIndex:0];
            [self _initiateNextInstallFromQueueWithTeamID:teamID
                                                 username:username
                                                 password:password];
        } else {
            // End the background task!
            [[UIApplication sharedApplication] endBackgroundTask:self.currentBackgroundTaskIdentifier];
            self.currentBackgroundTaskIdentifier = UIBackgroundTaskInvalid;
            
            self.undertakingResignPipeline = NO;
            
            // Notify of failure
            for (id<RPVApplicationSigningProtocol> observer in self.observers) {
                [observer applicationSigningCompleteWithError:error];
            }
        }
        
        return;
    }
    
    // Update progress to 30% for this application.
    for (id<RPVApplicationSigningProtocol> observer in self.observers) {
        [observer applicationSigningUpdateProgress:30 forBundleIdentifier:[application bundleIdentifier]];
    }
    
    //////////////////////////////////////////////////////////////////////////////////////
    // 2. Use libProvision to sign the .app
    //////////////////////////////////////////////////////////////////////////////////////
    
    [EEBackend signBundleAtPath:[applicationBundleURL path] username:username password:password priorChosenTeamID:teamID withCompletionHandler:^(NSError *error) {
        if (error) {
            // Callback to say we done "goofed".
            for (id<RPVApplicationSigningProtocol> observer in self.observers) {
                [observer applicationSigningDidEncounterError:error forBundleIdentifier:[application bundleIdentifier]];
            }
            
            // TODO: Cleanup the filesystem?
            
            // Start the next application off.
            if (self.installQueue.count > 1) {
                [self.installQueue removeObjectAtIndex:0];
                [self _initiateNextInstallFromQueueWithTeamID:teamID
                                                     username:username
                                                     password:password];
            } else {
                // End the background task!
                [[UIApplication sharedApplication] endBackgroundTask:self.currentBackgroundTaskIdentifier];
                self.currentBackgroundTaskIdentifier = UIBackgroundTaskInvalid;
                
                self.undertakingResignPipeline = NO;
                
                // Notify of failure
                for (id<RPVApplicationSigningProtocol> observer in self.observers) {
                    [observer applicationSigningCompleteWithError:error];
                }
            }
            
            return;
        }
        
        // Update progress to 50% for this application.
        for (id<RPVApplicationSigningProtocol> observer in self.observers) {
            [observer applicationSigningUpdateProgress:50 forBundleIdentifier:[application bundleIdentifier]];
        }
        
        //////////////////////////////////////////////////////////////////////////////////////
        // 3. Build IPA
        //////////////////////////////////////////////////////////////////////////////////////
        
        NSString *outputIpaPath = [NSString stringWithFormat:@"%@/%@.ipa", [EEBackend applicationTemporaryDirectory], [application bundleIdentifier]];
        
        NSError *err;
        if (![EEBackend repackIpaAtPath:[extractedArchiveURL path] toPath:outputIpaPath error:&err]) {
            
            // Callback to say we done "goofed".
            for (id<RPVApplicationSigningProtocol> observer in self.observers) {
                [observer applicationSigningDidEncounterError:error forBundleIdentifier:[application bundleIdentifier]];
            }
            
            // TODO: Cleanup the filesystem?
            
            // Start the next application off.
            if (self.installQueue.count > 1) {
                [self.installQueue removeObjectAtIndex:0];
                [self _initiateNextInstallFromQueueWithTeamID:teamID
                                                 username:username
                                                 password:password];
            } else {
                // End the background task!
                [[UIApplication sharedApplication] endBackgroundTask:self.currentBackgroundTaskIdentifier];
                self.currentBackgroundTaskIdentifier = UIBackgroundTaskInvalid;
                
                self.undertakingResignPipeline = NO;
                
                // Notify of failure
                for (id<RPVApplicationSigningProtocol> observer in self.observers) {
                    [observer applicationSigningCompleteWithError:error];
                }
            }
            
            return;
        }
        
        // Update progress to 60% for this application.
        for (id<RPVApplicationSigningProtocol> observer in self.observers) {
            [observer applicationSigningUpdateProgress:60 forBundleIdentifier:[application bundleIdentifier]];
        }
        
        //////////////////////////////////////////////////////////////////////////////////////
        // 4. Install IPA
        //////////////////////////////////////////////////////////////////////////////////////
        
        NSString *bundleIdentifier = [application bundleIdentifier];
        
        // Start the next application off at this point for some parallelism!
        if (self.installQueue.count > 1) {
            [self.installQueue removeObjectAtIndex:0];
            [self _initiateNextInstallFromQueueWithTeamID:teamID
                                             username:username
                                             password:password];
        } else {
            // Flag that we're done!
            self.undertakingResignPipeline = NO;
        }
        
        // And now we install!
        [self _installIpaAtPath:outputIpaPath withBundleIdentifier:bundleIdentifier];
    }];
}

@end
