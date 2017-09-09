//
//  EEPackageDatabase.m
//  Extender Installer
//
//  Created by Matt Clarke on 20/04/2017.
//
//

#import "EEPackageDatabase.h"
#import "EEPackage.h"
#import "EEResources.h"
#import "SSZipArchive.h"
#import <objc/runtime.h>
#include <unistd.h>

#import <notify.h>

@interface Extender : UIApplication
- (void)sendLocalNotification:(NSString*)title andBody:(NSString*)body;
-(void)sendLocalNotification:(NSString*)title body:(NSString*)body withID:(NSString*)identifier;
- (_Bool)application:(id)arg1 openURL:(id)arg2 sourceApplication:(id)arg3 annotation:(id)arg4;
- (void)beginResignRoutine:(int)location;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *teamID;
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSURL *bundleURL;
+ (instancetype)applicationProxyForIdentifier:(NSString*)arg1;
@end

@interface LSApplicationWorkspace : NSObject
+(instancetype)defaultWorkspace;
-(BOOL)installApplication:(NSURL*)arg1 withOptions:(NSDictionary*)arg2 error:(NSError**)arg3;
- (NSArray*)allApplications;
@end

@interface CydiaObject : NSObject
- (id)isReachable:(id)arg1;
@end

static EEPackageDatabase *sharedDatabase;

@implementation EEPackageDatabase

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        sharedDatabase = [[self alloc] init];
    });
    
    return sharedDatabase;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _queue = dispatch_queue_create("com.cydia.Extender.resignQueue", NULL);
        _currentBgTask = UIBackgroundTaskInvalid;
        
        _isLockedTaskQueued = NO;
        
        // TODO: Set _isLocked correctly for if we're currently UI locked.
        
        
        // Setup notifications for un/locking of the device.
        __weak EEPackageDatabase *weakSelf = self;
        
        uint32_t result = notify_register_dispatch("com.apple.springboard.lockstate",
                                                   &_notifyTokenForDidChangeDisplayStatus,
                                                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l),
                                                   ^(int info) {

            __strong EEPackageDatabase *strongSelf = weakSelf;
            if (strongSelf) {
                uint64_t state = UINT64_MAX;
                notify_get_state(_notifyTokenForDidChangeDisplayStatus, &state);
                
                if (state == 0) {
                    [strongSelf _didReceiveUnlockedNotification];
                } else {
                    [strongSelf _didReceiveLockedNotification];
                }
            }
            
        });
        
        if (result != NOTIFY_STATUS_OK) {
            // TODO: Handle error.
        }
        
        uint64_t state = UINT64_MAX;
        notify_get_state(_notifyTokenForDidChangeDisplayStatus, &state);
        
        _isLocked = state != 0;
    }
    
    return self;
}

- (void)dealloc {
    uint32_t result = notify_cancel(_notifyTokenForDidChangeDisplayStatus);
    
    if (result != NOTIFY_STATUS_OK) {
        // TODO: Handle error.
    }
}

- (void)_didReceiveLockedNotification {
    _isLocked = YES;
}

- (void)_didReceiveUnlockedNotification {
    _isLocked = NO;
    
    if (_isLockedTaskQueued) {
        _isLockedTaskQueued = NO;
        
        // Run queued task.
        [(Extender*)[UIApplication sharedApplication] beginResignRoutine:1];
        
        Extender *application = (Extender*)[UIApplication sharedApplication];
        [application sendLocalNotification:@"Queued Re-sign" andBody:@"The re-sign queued when your device was locked is now running."];
    }
}

- (NSArray *)retrieveAllTeamIDApplications {
    NSString *teamID = [EEResources getTeamID];
    
    if (!teamID || [teamID isEqualToString:@""]) {
        return [NSArray array];
    }
    
    NSMutableArray *identifiers = [NSMutableArray array];
    
    for (LSApplicationProxy *proxy in [[LSApplicationWorkspace defaultWorkspace] allApplications]) {
        if ([[proxy teamID] isEqualToString:teamID]) {
            [identifiers addObject:[proxy applicationIdentifier]];
        }
    }
    
    [identifiers removeObject:@"com.cydia.Extender"];
    
    _teamIDApplications = identifiers;
    
    return _teamIDApplications;
}

- (void)rebuildDatabase {
    /*
     * The database comprises of the bundle identifiers of applications with the current Team ID.
     */
    
    [self retrieveAllTeamIDApplications];
    
    // Check if the queue is still being walked.
    if (_installQueue.count != 0) {
        return;
    }
    
    NSString *inbox = [NSString stringWithFormat:@"%@/Unsigned", EXTENDER_DOCUMENTS];
    
    // Now, we cache the EEPackage for each IPA created.
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    for (NSString *bundleID in  _teamIDApplications) {
        EEPackage *package = [[EEPackage alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@.ipa", inbox, bundleID]] andBundleIdentifier:bundleID];
        
        [dict setObject:package forKey:[package bundleIdentifier]];
    }
    
    _packages = [dict copy];
    
    Extender *application = (Extender*)[UIApplication sharedApplication];
    [application sendLocalNotification:@"Debug" andBody:[NSString stringWithFormat:@"Rebuilt database, with %lu entries", (unsigned long)_packages.count]];
}

- (NSURL*)_buildIPAForExistingBundleIdentifier:(NSString*)bundleIdentifier {
    NSString *basePath = [NSString stringWithFormat:@"%@/Unsigned/%@/Payload", EXTENDER_DOCUMENTS, bundleIdentifier];
    
    // The attributes of ANY Extender folder should be write for ALL users and groups.
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSNumber numberWithShort:0777] forKey:NSFilePosixPermissions];
    [[NSFileManager defaultManager] createDirectoryAtPath:basePath withIntermediateDirectories:YES attributes:attributes error:nil];
    
    LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:bundleIdentifier];
    NSString *dotAppName = [[proxy.bundleURL path] lastPathComponent];
    
    NSString *fromPath = [proxy.bundleURL path];
    NSString *toPath = [NSString stringWithFormat:@"%@/Unsigned/%@/Payload/%@", EXTENDER_DOCUMENTS, bundleIdentifier, dotAppName];
    
    NSError *error;
    [[NSFileManager defaultManager] copyItemAtPath:fromPath toPath:toPath error:&error];
    
    if (error) {
        Extender *application = (Extender*)[UIApplication sharedApplication];
        [application sendLocalNotification:@"Debug" andBody:[NSString stringWithFormat:@"Could not copy .app (%@) from '%@' due to: %@", toPath, fromPath, error]];
    }
    
    // Compress into an ipa.
    BOOL success = [SSZipArchive createZipFileAtPath:[NSString stringWithFormat:@"%@/Unsigned/%@.ipa", EXTENDER_DOCUMENTS, bundleIdentifier] withContentsOfDirectory:[NSString stringWithFormat:@"%@/Unsigned/%@", EXTENDER_DOCUMENTS, bundleIdentifier]];
    
    if (!success) {
        // Well shit.
    }
    
    // Cleanup.
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/Unsigned/%@", EXTENDER_DOCUMENTS, bundleIdentifier] error:nil];
    
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/Unsigned/%@.ipa", EXTENDER_DOCUMENTS, bundleIdentifier]];
}

- (EEPackage*)packageForIdentifier:(NSString*)bundleIdentifier {
    return [_packages objectForKey:bundleIdentifier];
}

- (NSArray*)allPackages {
    return [_packages allValues];
}

- (void)resignApplicationsIfNecessaryWithTaskID:(UIBackgroundTaskIdentifier)bgTask andCheckExpiry:(BOOL)check {
    // Check if there is a current background task.
    if (_currentBgTask != UIBackgroundTaskInvalid && bgTask != _currentBgTask) {
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        return;
    } else if (_isLockedTaskQueued) {
        // We already have a task queued.
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        return;
    }
    
    _currentBgTask = bgTask;
    _currentCycleCount = 0;
    
    // If there is no Team ID or username, saved present "Sign In" notification.
    if (![EEResources username] || ![EEResources getTeamID]) {
        Extender *application = (Extender*)[UIApplication sharedApplication];
        [application sendLocalNotification:@"Sign In" body:@"Please login with your Apple ID to re-sign applications." withID:@"login"];
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        _currentBgTask = UIBackgroundTaskInvalid;
        return;
    }
    
    // If Low Power Mode is enabled, we will not attempt a resign to avoid power consumption, unless the user allows it.
    if ([[NSProcessInfo processInfo] isLowPowerModeEnabled] && check) {
        if (![EEResources shouldResignInLowPowerMode]) {
            Extender *application = (Extender*)[UIApplication sharedApplication];
            [application sendLocalNotification:@"Debug" andBody:@"Not proceeding to re-sign due to Low Power Mode being active."];
        
            [[UIApplication sharedApplication] endBackgroundTask:bgTask];
            _currentBgTask = UIBackgroundTaskInvalid;
            return;
        }
    }
    
    // We should also check network state before proceeding.
    CydiaObject *object = [[objc_getClass("CydiaObject") alloc] init];
    if (![[object isReachable:@"www.google.com"] boolValue]) {
        Extender *application = (Extender*)[UIApplication sharedApplication];
        [application sendLocalNotification:@"Debug" andBody:@"Not proceeding to re-sign due to no network access."];
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        _currentBgTask = UIBackgroundTaskInvalid;
        return;
    }
    
    Extender *application = (Extender*)[UIApplication sharedApplication];
    [application sendLocalNotification:@"Debug" andBody:@"Checking if any applications need re-signing."];
    
    NSDate *now = [NSDate date];
    unsigned int unitFlags = NSCalendarUnitDay;
    NSCalendar *currCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    // Create installQueue if needed.
    if (!_installQueue) {
        _installQueue = [NSMutableArray array];
    } else {
        [_installQueue removeAllObjects];
    }
    
    if (check) {
        for (EEPackage *package in [self allPackages]) {
            NSDate *expirationDate = [package applicationExpireDate];
            
            // If a nil expiration date is given, then the checks for days away will always be true.
            if (!expirationDate) {
                continue;
            }
            
            NSDateComponents *conversionInfo = [currCalendar components:unitFlags fromDate:now toDate:expirationDate options:0];
            int days = (int)[conversionInfo day];
        
            if (days < [EEResources thresholdForResigning]) {
                [_installQueue addObject:[package bundleIdentifier]];
            }
        }
    } else {
        for (EEPackage *package in [self allPackages]) {
            [_installQueue addObject:[package bundleIdentifier]];
        }
    }
    
    if (_installQueue.count == 0 && [EEResources shouldShowNonUrgentAlerts]) {
        Extender *application = (Extender*)[UIApplication sharedApplication];
        [application sendLocalNotification:nil andBody:@"No applications need re-signing at this time."];
    }
    
    if (_installQueue.count > 0 && _isLocked) {
        // The device is locked, so cannot run until unlocked.
        _isLockedTaskQueued = YES;
            
        // Send an alert stating for the user to unlock if they want to re-sign.
        Extender *application = (Extender*)[UIApplication sharedApplication];
        [application sendLocalNotification:@"Unlock Device" body:@"A re-sign will occur when you next unlock your device." withID:@"unlock-pls"];
            
        // End the incoming task early, as we will spawn another when we receive an unlocked notification.
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        _currentBgTask = UIBackgroundTaskInvalid;
        
        [_installQueue removeAllObjects];
        
        return;
    }
    
    // Send out all the notifications needed to set UI to show 0% for re-signing applications.
    for (NSString *identifier in _installQueue) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setObject:identifier forKey:@"identifier"];
        [dict setObject:[NSNumber numberWithFloat:0.0] forKey:@"percent"];
        [dict setObject:[NSNumber numberWithBool:NO] forKey:@"animated"];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"EEDidUpdateResignProgress" object:nil userInfo:dict];
    }
    
    // Clear current IPAs.
    NSString *inbox = [NSString stringWithFormat:@"%@/Unsigned", EXTENDER_DOCUMENTS];
    [[NSFileManager defaultManager] removeItemAtPath:inbox error:nil];
    
    // The attributes of ANY Extender folder should be write for ALL users and groups.
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSNumber numberWithShort:0777] forKey:NSFilePosixPermissions];
    [[NSFileManager defaultManager] createDirectoryAtPath:inbox withIntermediateDirectories:YES attributes:attributes error:nil];
    
    // Cleanup any expired or old certificates that are no longer in use.
    [EEResources cleanupExpiredProvisioningCertificatesWithCompletionHandler:^(BOOL success) {
        // Note that this WILL modify the queue, so any checks for count should be done before.
        [self _initiateNextInstallFromQueue];
    }];
}

- (void)_initiateNextInstallFromQueue {
    if ([_installQueue count] == 0) {
        // We can exit now.
        [[UIApplication sharedApplication] endBackgroundTask:_currentBgTask];
        _currentBgTask = UIBackgroundTaskInvalid;
    } else {
        // Pull next off the front of the array.
        NSString *identifier = [[_installQueue firstObject] copy];
        [_installQueue removeObjectAtIndex:0];
        
        EEPackage *package = [self packageForIdentifier:identifier];
        [self resignPackage:package];
    }
}

- (void)resignPackage:(EEPackage*)package {
    // Note that we come into here on the global queue for async. We need a new queue on which to place
    // a resign request, else it'll block.
    
    // Update progress percent in the UI.
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:package.bundleIdentifier forKey:@"identifier"];
    [dict setObject:[NSNumber numberWithFloat:10.0] forKey:@"percent"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"animated"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"EEDidUpdateResignProgress" object:nil userInfo:dict];
    
    // Build the IPA for this application now.
    [self _buildIPAForExistingBundleIdentifier:[package bundleIdentifier]];
    
    Extender *application = (Extender*)[UIApplication sharedApplication];
    [application sendLocalNotification:@"Debug" andBody:[NSString stringWithFormat:@"Requesting re-sign for: '%@'", [package applicationName]]];
    
    // Update progress percent in the UI.
    dict = [NSMutableDictionary dictionary];
    [dict setObject:package.bundleIdentifier forKey:@"identifier"];
    [dict setObject:[NSNumber numberWithFloat:30.0] forKey:@"percent"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"animated"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"EEDidUpdateResignProgress" object:nil userInfo:dict];
    
    // Clear any existing provisioning profile for this application, if available.
    
    [EEResources removeExistingProvisioningProfileForApplication:[package bundleIdentifier] withCallback:^(BOOL success) {
        if (success) {
            [application sendLocalNotification:@"Debug" andBody:[NSString stringWithFormat:@"Removed profile for: '%@'", [package applicationName]]];
        }
        
        dispatch_async(_queue, ^{
            [application application:application openURL:[package packageURL] sourceApplication:application annotation:nil];
        });
    }];
}

- (void)errorDidOccur:(NSString*)message {    
    // When any error occurs, clear the installation queue so we can try again later.
    [_installQueue removeAllObjects];
    
    // Send out all the notifications needed to set UI to hide progress bars.
    for (NSString *identifier in _teamIDApplications) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setObject:identifier forKey:@"identifier"];
        [dict setObject:[NSNumber numberWithFloat:-5.0] forKey:@"percent"];
        [dict setObject:[NSNumber numberWithBool:NO] forKey:@"animated"];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"EEDidUpdateResignProgress" object:nil userInfo:dict];
    }
    
    // The meat of the error message is 2x \n in.
    NSArray *split = [message componentsSeparatedByString:@"\n"];
    
    NSString *meat = [split lastObject];
    if (split.count > 3) {
        // Combine the end strings into one.
        
        NSMutableString *str = [@"" mutableCopy];
        
        for (int i = 2; i < split.count; i++) {
            [str appendFormat:@"%@%@", i == 2 ? @"" : @"\n", [split objectAtIndex:i]];
        }
        
        meat = str;
    }
    
    NSString *errorMessage = [NSString stringWithFormat:@"%@\n(%@)", meat, [split objectAtIndex:1]];
    
    if (split.count == 2) {
        errorMessage = [split lastObject];
    }
    
    // We may be able to handle this ourselves.
    NSString *errorReason = [split objectAtIndex:1];
    if ([errorReason isEqualToString:@"ios/submitDevelopmentCSR =7460"]) {
        // Attempt an auto-revoke if enabled.
        
        if ([EEResources shouldAutoRevokeIfNeeded] && _currentCycleCount == 0 && !_isRevoking) {
            // Make sure we don't get called to revoke twice.
            _isRevoking = YES;
            
            Extender *application = (Extender*)[UIApplication sharedApplication];
            [application sendLocalNotification:@"Debug" andBody:@"Attempting to revoke certificates"];
            
            [EEResources _actuallyRevokeCertificatesWithAlert:nil andCallback:^(BOOL success) {
                if (success) {
                    // Restart this installation cycle.
                    
                    // This is a very important alert!
                    [application sendLocalNotification:nil andBody:@"Automatically revoked certificates to resolve an error.\nYou will receieve an email about this, which can be ignored."];
                    
                     // Since we have revoked certificates, ALL applications must be re-signed.
                    [self resignApplicationsIfNecessaryWithTaskID:_currentBgTask andCheckExpiry:NO];
                    
                    // So that we don't loop infinitely here.
                    _currentCycleCount++;
                } else {
                    // Alert the user.
                    [application sendLocalNotification:@"Error" body:@"Could not automatically revoke certificates" withID:@"lastError"];
                }
                
                _isRevoking = NO;
            }];
            
            return;
        } else if (![EEResources shouldAutoRevokeIfNeeded]) {
            // Now, display to the user we had an error.
            Extender *application = (Extender*)[UIApplication sharedApplication];
            [application sendLocalNotification:@"Error" body:[NSString stringWithFormat:@"%@\n\nTry enabling \"Auto-Revoke Certificates\" in the Advanced panel to resolve this, or tap \"Revoke Certificates\" in the Troubleshooting panel.", [split lastObject]] withID:@"lastError"];
            
            // Exit the current background task.
            [[UIApplication sharedApplication] endBackgroundTask:_currentBgTask];
            _currentBgTask = UIBackgroundTaskInvalid;
            
            return;
        }
    }
    
    // Now, display to the user we had an error.
    Extender *application = (Extender*)[UIApplication sharedApplication];
    [application sendLocalNotification:@"Error" body:errorMessage withID:@"lastError"];
    
    // Exit the current background task.
    [[UIApplication sharedApplication] endBackgroundTask:_currentBgTask];
    _currentBgTask = UIBackgroundTaskInvalid;
}

- (void)installPackageAtURL:(NSURL*)url withManifest:(NSDictionary*)manifest {
    Extender *application = (Extender*)[UIApplication sharedApplication];
    
    // The manifest will contain the bundleIdentifier and the display name.
    NSDictionary *item = [[manifest objectForKey:@"items"] firstObject];
    NSDictionary *metadata = [item objectForKey:@"metadata"];
    
    NSString *bundleID = [metadata objectForKey:@"bundle-identifier"];
    NSString *title = [metadata objectForKey:@"title"];
    
    // There is a possibility we may be called twice here!
    if ([url isFileURL] && ![[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
        return;
    }
    
    // Update progress percent in the UI.
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:bundleID forKey:@"identifier"];
    [dict setObject:[NSNumber numberWithFloat:60.0] forKey:@"percent"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"animated"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"EEDidUpdateResignProgress" object:nil userInfo:dict];
    
    // Move this package to Documents/Extender/Signed/<uniquename>.ipa
    
    // The attributes of ANY Extender folder should be write for ALL users and groups.
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSNumber numberWithShort:0777] forKey:NSFilePosixPermissions];
    [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/Signed/", EXTENDER_DOCUMENTS]
                              withIntermediateDirectories:YES
                                               attributes:attributes
                                                    error:nil];
    
    NSError *error1;
    NSString *pkgName = [NSString stringWithFormat:@"pkg_%f", [[NSDate date] timeIntervalSince1970]];
    NSString *toPath = [NSString stringWithFormat:@"%@/Signed/%@.ipa", EXTENDER_DOCUMENTS, pkgName];
    
    if (![[NSFileManager defaultManager] copyItemAtPath:[url path] toPath:toPath error:&error1] || error1) {
        NSLog(@"ERROR: %@", error1);
        
        [application sendLocalNotification:@"Debug" andBody:[NSString stringWithFormat:@"Failed to copy to path: '%@', with error: %@", toPath, error1.description]];
        
        return;
    }
    
    url = [NSURL fileURLWithPath:toPath];
    
    // Update progress percent in the UI.
    dict = [NSMutableDictionary dictionary];
    [dict setObject:bundleID forKey:@"identifier"];
    [dict setObject:[NSNumber numberWithFloat:75.0] forKey:@"percent"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"animated"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"EEDidUpdateResignProgress" object:nil userInfo:dict];
    
    // We can now begin installation, and allow us to move onto the next application.
    dispatch_async(_queue, ^{
        NSError *error;
        NSDictionary *options = @{@"CFBundleIdentifier" : bundleID, @"AllowInstallLocalProvisioned" : [NSNumber numberWithBool:YES]};
    
        BOOL result = [[LSApplicationWorkspace defaultWorkspace] installApplication:url
                                                      withOptions:options
                                                            error:&error];
        
        // Update progress percent in the UI.
        NSMutableDictionary *dict2 = [NSMutableDictionary dictionary];
        [dict2 setObject:bundleID forKey:@"identifier"];
        [dict2 setObject:[NSNumber numberWithFloat:90.0] forKey:@"percent"];
        [dict2 setObject:[NSNumber numberWithBool:YES] forKey:@"animated"];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"EEDidUpdateResignProgress" object:nil userInfo:dict2];
    
        if (!result) {
            [application sendLocalNotification:@"Failed" andBody:[NSString stringWithFormat:@"Failed to re-sign: '%@'.\nError: %@", title, error.localizedDescription]];
        } else {
            // Note that we should change the alert's text based upon if the user has installed this application before.
            
            LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:bundleID];
            
            [application sendLocalNotification:@"Success" body:[NSString stringWithFormat:@"%@: '%@'", proxy != nil ? @"Re-signed" : @"Installed", title] withID:bundleID];
        }
    
        // Clean up.
        [[NSFileManager defaultManager] removeItemAtPath:toPath error:nil];
        
        // Update progress percent in the UI.
        dict2 = [NSMutableDictionary dictionary];
        [dict2 setObject:bundleID forKey:@"identifier"];
        [dict2 setObject:[NSNumber numberWithFloat:100.0] forKey:@"percent"];
        [dict2 setObject:[NSNumber numberWithBool:YES] forKey:@"animated"];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"EEDidUpdateResignProgress" object:nil userInfo:dict2];
        
        // Let UI know there's updates to be had.
        [[NSNotificationCenter defaultCenter] postNotificationName:@"EEDidSignApplication" object:nil];
    });
    
    // Signal that we can continue to the next application, as we've signed this one and queued it for installation.
    [self _initiateNextInstallFromQueue];
}

@end
