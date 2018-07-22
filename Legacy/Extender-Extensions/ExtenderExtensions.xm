//
//  Extender_Extensions
//  Extender Installer
//
//  Created by Matt Clarke on 13/04/2017.
//  Copyright (c) 2017 Matchstic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EEPackagesViewController.h"
#import "EESettingsController.h"
#import "EEPackage.h"
#import "EEPackageDatabase.h"
#import "EEResources.h"
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>

#import "SAMKeychain.h"

/////////////////////////////////////////////////////////////////////
// Interface declarations

@interface InstalledController : UIViewController
@end

@interface Extender : UIApplication
-(void)sendLocalNotification:(NSString*)title andBody:(NSString*)body;
-(void)sendLocalNotification:(NSString*)title body:(NSString*)body withID:(NSString*)identifier;
- (void)beginResignRoutine:(int)location;
- (void)resignApplication:(EEPackage*)package;
- (void)registerForRemoteNotificationTypes:(unsigned long long)arg1;
- (void)_resignTimerCallback:(id)sender;
- (void)_requestAppleDeveloperLogin;
- (void)_reloadHeartbeatTimer;

- (_Bool)application:(id)arg1 openURL:(id)arg2 sourceApplication:(id)arg3 annotation:(id)arg4;
@end

@interface SBApplication : NSObject
- (id)bundleIdentifier;
@end

@interface UIAlertController (Private)
- (void)_dismissWithAction:(UIAlertAction*)arg1;
@end

@interface UIAlertAction (Private)
- (id /* block */)handler;
@end

/////////////////////////////////////////////////////////////////////
// Static variables

static EEPackagesViewController *packagesController;
static EESettingsController *settingsController;
static NSTimer *heartbeatTimer;
dispatch_queue_t resignQueue;

/////////////////////////////////////////////////////////////////////
// Hooks (Extender)

%group Extender

/*
 * We will provide:
 * a) Background app refresh for auto-signing of applications
 * b) Storage of local IPA files for auto-signing
 * c) Caching of user login details to facilitate auto-signing
 * d) Settings to manage the above.
 */

#pragma mark Insert new pages

%hook Extender

- (NSArray*)defaultStartPages {
    NSArray *original = %orig;
    
    NSMutableArray *additions = [original mutableCopy];
    [additions addObject:@[@"cyext://settings"]];
    
    return additions;
}

- (UIViewController *) pageForURL:(NSURL *)url forExternal:(BOOL)external withReferrer:(NSString *)referrer {
    if (url) {
        NSString *scheme = [[url scheme] lowercaseString];
        
        if (scheme && [scheme isEqualToString:@"cyext"]) {
            if ([[url absoluteString] isEqualToString:@"cyext://installed"]) {
                
                if (!packagesController) {
                    packagesController = [[EEPackagesViewController alloc] init];
                }
                
                return packagesController;
            } else if ([[url absoluteString] isEqualToString:@"cyext://settings"]) {
                
                if (!settingsController) {
                    settingsController = [[EESettingsController alloc] init];
                }
                
                return settingsController;
            }
        }	
    }
    
    return %orig;
}

%end

%hook CyextTabBarController

- (void)setViewControllers:(NSArray*)arg1 {
    
    NSMutableArray *controllers([arg1 mutableCopy]);
    
    UITabBarItem *item2 = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemMore tag:0];
    UINavigationController *controller2 = [[UINavigationController alloc] init];
    [controller2 setTabBarItem:item2];
    [controllers addObject:controller2];
    
    %orig(controllers);
}

%end

#pragma mark Notifications handling

%hook Extender

%new
-(void)sendLocalNotification:(NSString*)title body:(NSString*)body withID:(NSString*)identifier {
    // We can assume that some users will not want any notifications at all.
    // Thus, provide a setting for that.
    
    if ([title isEqualToString:@"Debug"] && ![EEResources shouldShowDebugAlerts]) {
        return;
    }
    
    UNMutableNotificationContent *objNotificationContent = [[UNMutableNotificationContent alloc] init];
    
    objNotificationContent.title = title;
    objNotificationContent.body = body;
    objNotificationContent.sound = nil;
    
    // Update application icon badge number if applicable
    objNotificationContent.badge = @([[UIApplication sharedApplication] applicationIconBadgeNumber]);
    
    // Set time of notification being triggered
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger                                             triggerWithTimeInterval:1 repeats:NO];
    
    UNNotificationRequest *request = [UNNotificationRequest
                                      requestWithIdentifier:identifier                                                                   content:objNotificationContent trigger:trigger];
    
    // Schedule localNotification
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        
    }];
}

%new
-(void)sendLocalNotification:(NSString*)title andBody:(NSString*)body {
    [self sendLocalNotification:title body:body withID:[NSString stringWithFormat:@"notif_%f", [[NSDate date] timeIntervalSince1970]]];
}

#pragma mark Request user Apple ID from opening relevant notification.

%new
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    
    NSString *identifier = response.notification.request.identifier;
    
    if ([identifier isEqualToString:@"login"]) {
        // Present login UI.
        [self _requestAppleDeveloperLogin];
    }
    
    completionHandler();
}

%new
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    // Ensure that alerts will display in-app.
    completionHandler(UNNotificationPresentationOptionAlert);
}

%new
- (void)_requestAppleDeveloperLogin {
    [EEResources signInWithCallback:^(BOOL result, NSString *username) {}];
}

#pragma mark Callbacks for background execution

- (void)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)options {
    %orig;
    
    resignQueue = dispatch_queue_create("com.cydia.Extender.queue", NULL);
    
    [self _reloadHeartbeatTimer];
    
    // Kick off first check.
    [self beginResignRoutine:0];
    
    // Register to send the user notifications.
    if ([self respondsToSelector:@selector(registerUserNotificationSettings:)]) {        
        [self registerUserNotificationSettings:[objc_getClass("UIUserNotificationSettings") settingsForTypes:7 categories:nil]];
        [self registerForRemoteNotifications];
    } else {
        [self registerForRemoteNotificationTypes:7];
    }
    
    // For responding to notifications.
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = (id<UNUserNotificationCenterDelegate>)self;

    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert) completionHandler:^(BOOL granted, NSError * _Nullable error) {
         if (error) {
             // Failure to register for notifications.
         }
    }];
    
    // Setup Keychain accessibility for when locked.
    // (prevents not being able to correctly read the passcode when the device is locked)
    [SAMKeychain setAccessibilityType:kSecAttrAccessibleAfterFirstUnlock];
}

%new
- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Did enter background!
    
    // XXX: We do not need to call re-sign at this point, as real-world testing has proven that
    // this is only reached when the Extender application moved from Foreground to Suspended.
    //[self beginResignRoutine:1];
}

%new
-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    [self beginResignRoutine:2];
    
    completionHandler(UIBackgroundFetchResultNoData);
}

%new
- (void)_reloadHeartbeatTimer {
    NSTimeInterval interval = [EEResources heartbeatTimerInterval];
    
    if (heartbeatTimer) {
        [heartbeatTimer invalidate];
        heartbeatTimer = nil;
    }
    
    heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(_resignTimerCallback:) userInfo:nil repeats:YES];
    
    // Setup fetch interval - allows the timer to run if this application becomes suspended.
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:interval];
}

%new
- (void)_resignTimerCallback:(id)sender {
    [self beginResignRoutine:3];
}

%new
- (void)beginResignRoutine:(int)location {
    // User wishes not to automatically re-sign.
    if (![EEResources shouldAutomaticallyResign]) {
        return;
    }
    
    UIApplication *application = [UIApplication sharedApplication];
    UIBackgroundTaskIdentifier __block bgTask = [application beginBackgroundTaskWithName:@"Cydia Extender Auto Sign" expirationHandler:^{
        
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    // Start the long-running task and return immediately.
    dispatch_async(resignQueue, ^{
        // Sign the downloaded applications in turn, and attempt installations.
        
        [[EEPackageDatabase sharedInstance] rebuildDatabase];
        [[EEPackageDatabase sharedInstance] resignApplicationsIfNecessaryWithTaskID:bgTask andCheckExpiry:YES];
    });
}

%end

#pragma mark Auto-fill user Apple ID details.

%hook UIAlertController

// TODO: We should be preventing this alert controller from showing in the first place
// Currently, users are getting confused why the alert insta-hides without interaction.

- (void)_logBeingPresented {
    
    BOOL hasCachedUser = [EEResources username] != nil;
    
    if (hasCachedUser && [self.title isEqualToString:@"Apple Developer"]) {
        // Auto-fill and call the first action handler.
        NSArray *textFields = [self textFields];
        
        if (textFields.count == 2) {
            // index 0: username
            // index 1: password
            
            // Password is in the keychain.
            NSString *username = [EEResources username];
            NSString *password = [EEResources password];
            
            // Set details into the textfields. Note that index 0 is the username field.
            UITextField *userField = [textFields objectAtIndex:0];
            userField.text = username;
            
            UITextField *passField = [textFields objectAtIndex:1];
            passField.text = password;
            
            // Once done, we can do _dismissWithAction: on the Attempt action, which will allow us to forward
            // on the details through to Extender.
            
            UIAlertAction *attemptAction;
            for (UIAlertAction *action in self.actions) {
                if ([action.title isEqualToString:@"Attempt"]) {
                    attemptAction = action;
                    break;
                }
            }
            
            // Dismiss, calling this action.
            [self _dismissWithAction:attemptAction];
        }
        // XXX: Handle errors.
    } else if ([self.title isEqualToString:[[NSBundle mainBundle] localizedStringForKey:@"ERROR" value:@"ERROR" table:nil]]) {
        [[EEPackageDatabase sharedInstance] errorDidOccur:self.message];
        
        // There is only one action for an "error" alert.
        UIAlertAction *closeAction = [self.actions firstObject];
        
        // XXX: Do we need to call it manually like this?
        [self _dismissWithAction:closeAction];
    } else {
        %orig;
    }
}

%end

#pragma mark Override default IPA from URL behaviour

%hook Extender

- (_Bool)application:(UIApplication*)arg1 openURL:(NSURL*)url sourceApplication:(UIApplication*)arg3 annotation:(id)arg4 {
    if (arg3 != self) {
        // We are attempting to load this URL from outside Extender.
        
        // In this situation, we will initiate an installation, and show a banner to the user.
        [self sendLocalNotification:@"Installing" andBody:@"Application is being installed."];
        
        return %orig;
    } else {
        // Attempting to re-sign from within ourselves.
        return %orig;
    }
}

%end

#pragma mark Install signed IPA

%hook NSFileManager

- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    return [NSURL fileURLWithPath:EXTENDER_DOCUMENTS];
}

%end

%hook Extender

- (BOOL)openURL:(NSURL*)url {
    if ([[url absoluteString] rangeOfString:@"itms-services"].location != NSNotFound) {
        // Grab the signed.ipa file, and send to EEPackageDatabase for installation.
        
        NSString *path = [EXTENDER_DOCUMENTS stringByAppendingString:@"/Site/signed.ipa"];
        NSURL *pathURL = [NSURL fileURLWithPath:path];
        
        path = [EXTENDER_DOCUMENTS stringByAppendingString:@"/Site/manifest.plist"];
        NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:path];
        
        [[EEPackageDatabase sharedInstance] installPackageAtURL:pathURL withManifest:manifest];
        
        return YES;
    } else {
        return %orig;
    }
}

%end

#pragma mark Look ma, no VPN!

%hook NEVPNConnection

- (BOOL)startVPNTunnelAndReturnError:(NSError **)error {
    return YES; // Fakes that the VPN started correctly when requested.
}

- (int)status {
    // Defined as connected here: https://developer.apple.com/reference/networkextension/nevpnstatus/1406842-connected
    return 3;
}

%end

%hook NEVPNManager

- (void)saveToPreferencesWithCompletionHandler:(void (^)(NSError *error))completionHandler {
    completionHandler(nil);
    return; // Do not attempt to save the new VPN configuration.
}

%end

%hook NETunnelProviderManager

+ (void)loadAllFromPreferencesWithCompletionHandler:(void (^)(NSArray *managers, NSError *error))completionHandler {
    completionHandler([NSArray array], nil); // Load up empty preferences.
}

%end

#pragma mark Don't time out for debug.txt opening.

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    
    if ([[url path] rangeOfString:@"debug.txt"].location != NSNotFound) {
        completionHandler([NSData dataWithBytes:"hello" length:6], nil, nil);
        return nil;
    } else {
        return %orig;
    }
}

%end

#pragma mark Fixes for UNUserNotificationCenter and stashing

%hook UNUserNotificationCenter

-(id)initWithBundleIdentifier:(NSString*)bundleID {
    id result;
    
    if (!bundleID) {
        bundleID = @"com.cydia.Extender";
    }
    
    @try {
        result = %orig;
    } @catch (NSException *e) {
        result = %orig(@"com.cydia.Extender");
    }
    
    return result;
}

%end

#pragma mark Hook Team ID into csops().

/* We need a hook for setting the Team ID into saurik's code.
 * His approach is to read it via csops() into a plist, and then does effectively:
 * [entitlements objectForKey:@"com.apple.developer.team-identifier"];
 *
 * We could hook csops() directly, though that returns a bplist, which will be a pain to
 * work with.
 *
 * However, the main issue is that no Objective-C is used for plist handling.
 * Thus, we need to hook a C or C++ function somewhere in plist_from_bin in Extender.dylib.
 *
 * The implmentation for this comes from: https://github.com/julioverne/Extendlife/blob/master/Extendlife.xm#L40
 */
%hookf(size_t, strlen, const char *str) {
    size_t len = %orig(str);
    
    if (strncmp(str, "AAAAAAAAAA", 10) == 0 && len == 10) {
        NSString *teamID = [EEResources getTeamID];
        if (teamID)
            memcpy((void*)str, (const void *)[teamID UTF8String], 10);
    }
    
    return %orig(str);
}

%end

/////////////////////////////////////////////////////////////////////
// Hooks (SpringBoard)

%group SpringBoard

#pragma mark Force auto-relaunch, and backgrounding

%hook SBApplication

- (_Bool)shouldAutoLaunchOnBootOrInstall {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return %orig;
}

- (_Bool)_shouldAutoLaunchOnBootOrInstall:(_Bool)arg1 {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return %orig;
}

- (_Bool)_shouldAutoLaunchForVoIP {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return %orig;
}

- (_Bool)shouldAutoRelaunchAfterExit {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return %orig;
}

- (_Bool)supportsFetchBackgroundMode {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return %orig;
}

- (_Bool)supportsBackgroundAppRefresh {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return %orig;
}

- (_Bool)supportsRemoteNotificationBackgroundMode {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return %orig;
}

%end

%end


%ctor {
    %init;

    // Specific application initialisation.
    BOOL sb = [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
    
    if (sb) {
        %init(SpringBoard);
    } else {
        %init(Extender);
    }
}
