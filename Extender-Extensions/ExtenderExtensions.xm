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
    [EEResources signInWithCallback:^(BOOL result) {}];
}

#pragma mark Callbacks for background execution

- (void)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)options {
    %orig;
    
    resignQueue = dispatch_queue_create("com.cydia.Extender.queue", NULL);
    
    // Setup fetch interval.
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:7200];
    
    // And a timer for good measure.
    heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:3600 target:self selector:@selector(_resignTimerCallback:) userInfo:nil repeats:YES];
    
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
- (void)_resignTimerCallback:(id)sender {
    [self beginResignRoutine:3];
}

%new
- (void)beginResignRoutine:(int)location {
    
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

// There is a possibility here that the user's development certificate needs to be revoked for some reason.
// Error is "provison.cpp:81\nios/submitDevelopmentCSR =7460"
// Thus, we will attempt to automatically handle that here.

%hook UIAlertController

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
            
            // XXX: Do we need to call it manually like this?
            void (^handler)(UIAlertAction*) = attemptAction.handler;
            handler(attemptAction);
            [self _dismissWithAction:attemptAction];
        }
    } else if ([self.title isEqualToString:@"Error"]) {
        [[EEPackageDatabase sharedInstance] errorDidOccur:self.message];
        
        // There is only one action for an "error" alert.
        UIAlertAction *closeAction = [self.actions firstObject];
        
        // XXX: Do we need to call it manually like this?
        void (^handler)(UIAlertAction*) = closeAction.handler;
        handler(closeAction);
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
