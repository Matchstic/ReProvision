//
//  AppDelegate.m
//  ReProvision
//
//  Created by Matt Clarke on 08/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "AppDelegate.h"
#import "RPVResources.h"
#import "RPVNotificationManager.h"
#import "RPVBackgroundSigningManager.h"
#import "RPVResources.h"

#import "RPVIpaBundleApplication.h"
#import "RPVApplicationDetailController.h"

#import <RMessageView.h>
#import "SAMKeychain.h"

#include <notify.h>

@interface AppDelegate ()

@property (nonatomic, readwrite) int daemonNotificationToken;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)arg1 willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
     NSLog(@"*** [ReProvision] :: applicationWillFinishLaunching, options: %@", launchOptions);
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [[RPVApplicationSigning sharedInstance] addSigningUpdatesObserver:self];
    
    // Register to send notifications
    [[RPVNotificationManager sharedInstance] registerToSendNotifications];
    
    // Register for background signing notifications.
    [self _registerForDaemonNotifications];
    
    // Setup Keychain accessibility for when locked.
    // (prevents not being able to correctly read the passcode when the device is locked)
    [SAMKeychain setAccessibilityType:kSecAttrAccessibleAfterFirstUnlock];
    
    // Tint colour
    [self.window setTintColor:[UIColor colorWithRed:147.0/255.0 green:99.0/255.0 blue:207.0/255.0 alpha:1.0]];
    
    // Stuff for RMessage (iOS 9 only)
    [[RMessageView appearance] setMessageIcon:[UIImage imageNamed:@"notifIcon"]];
    [[RMessageView appearance] setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:0.9]];
    
    NSLog(@"*** [ReProvision] :: applicationDidFinishLaunching, options: %@", launchOptions);
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // nop
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Launched in background by daemon, or when exiting the application.
    NSLog(@"*** [ReProvision] :: applicationDidEnterBackground");
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // nop
    NSLog(@"*** [ReProvision] :: applicationWillEnterForeground");
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // nop
    NSLog(@"*** [ReProvision] :: applicationDidBecomeActive");
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    
    // Incoming URL is a fileURL!
    
    // Create an RPVApplication for this incoming .ipa, and display the installation popup.
    RPVIpaBundleApplication *ipaApplication = [[RPVIpaBundleApplication alloc] initWithIpaURL:url];
    
    RPVApplicationDetailController *detailController = [[RPVApplicationDetailController alloc] initWithApplication:ipaApplication];
    
    // Update with current states.
    [detailController setButtonTitle:@"INSTALL"];
    
    // Add to the rootViewController of the application, as an effective overlay.
    detailController.view.alpha = 0.0;
    
    UIViewController *rootController = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rootController addChildViewController:detailController];
    [rootController.view addSubview:detailController.view];
    
    detailController.view.frame = rootController.view.bounds;
    
    // Animate in!
    [detailController animateForPresentation];
    
    return YES;
}

//////////////////////////////////////////////////////////////////////////////////
// Application Signing delegate methods.
//////////////////////////////////////////////////////////////////////////////////

- (void)applicationSigningDidStart {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.matchstic.reprovision/signingInProgress" object:nil];
    NSLog(@"Started signing...");
}

- (void)applicationSigningUpdateProgress:(int)percent forBundleIdentifier:(NSString *)bundleIdentifier {
    NSLog(@"'%@' at %d%%", bundleIdentifier, percent);
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:bundleIdentifier forKey:@"bundleIdentifier"];
    [userInfo setObject:[NSNumber numberWithInt:percent] forKey:@"percent"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.matchstic.reprovision/signingUpdate" object:nil userInfo:userInfo];
    
    switch (percent) {
        case 100:
            [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"Success" body:[NSString stringWithFormat:@"Signed '%@'", bundleIdentifier] isDebugMessage:NO andNotificationID:nil];
            break;
        case 10:
            [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"DEBUG" body:[NSString stringWithFormat:@"Started signing routine for '%@'", bundleIdentifier] isDebugMessage:YES andNotificationID:nil];
            break;
        case 50:
            [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"DEBUG" body:[NSString stringWithFormat:@"Wrote signatures for bundle '%@'", bundleIdentifier] isDebugMessage:YES andNotificationID:nil];
            break;
        case 60:
            [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"DEBUG" body:[NSString stringWithFormat:@"Rebuilt IPA for bundle '%@'", bundleIdentifier] isDebugMessage:YES andNotificationID:nil];
            break;
        case 90:
            [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"DEBUG" body:[NSString stringWithFormat:@"Installing IPA for bundle '%@'", bundleIdentifier] isDebugMessage:YES andNotificationID:nil];
            break;
            
        default:
            break;
    }
}

- (void)applicationSigningDidEncounterError:(NSError *)error forBundleIdentifier:(NSString *)bundleIdentifier {
    NSLog(@"'%@' had error: %@", bundleIdentifier, error);
    [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"Error" body:[NSString stringWithFormat:@"For '%@'\n%@", bundleIdentifier, error.localizedDescription] isDebugMessage:NO isUrgentMessage:YES andNotificationID:nil];
    
    // Ensure the UI goes back to when signing was not occuring
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:bundleIdentifier forKey:@"bundleIdentifier"];
    [userInfo setObject:[NSNumber numberWithInt:100] forKey:@"percent"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.matchstic.reprovision/signingUpdate" object:nil userInfo:userInfo];
}

- (void)applicationSigningCompleteWithError:(NSError *)error {
    NSLog(@"Completed signing, with error: %@", error);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.matchstic.reprovision/signingComplete" object:nil];
    
    // Display any errors if needed.
    if (error) {
        switch (error.code) {
            case RPVErrorNoSigningRequired:
                [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"Success" body:@"No applications require signing at this time" isDebugMessage:NO isUrgentMessage:YES andNotificationID:nil];
                break;
            default:
                [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"Error" body:error.localizedDescription isDebugMessage:NO isUrgentMessage:YES andNotificationID:nil];
                break;
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Automatic application signing
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)_registerForDaemonNotifications {
    int status;
    static char first = 0;
    
    if (!first) {
        status = notify_register_check("com.matchstic.reprovision.ios/applicationNotification", &_daemonNotificationToken);
        if (status != NOTIFY_STATUS_OK) {
            fprintf(stderr, "registration failed (%u)\n", status);
            return;
        }
        
        first = 1;
    }
    
    // Handle when we're open and get a background request come through.
    status = notify_register_dispatch("com.matchstic.reprovision.ios/applicationNotification", &_daemonNotificationToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0l), ^(int info) {
        
        NSLog(@"*** [ReProvision] :: Got a background signing request when open.");
        
        [self _didRecieveDaemonNotification];
    });
    
    // And do a check now for if we need to sign.
    [self _checkForDaemonNotification];
}

- (void)_checkForDaemonNotification {
    // Check the daemon's notification state.
    
    int status, check;
    status = notify_check(_daemonNotificationToken, &check);
    if (status == NOTIFY_STATUS_OK && check != 0) {
        [self _didRecieveDaemonNotification];
    }
}

- (void)_didRecieveDaemonNotification {
    uint64_t incoming = 0;
    notify_get_state(_daemonNotificationToken, &incoming);
    
    NSLog(@"*** [ReProvision] :: daemon notification received. State: %d", (int)incoming);
    
    switch (incoming) {
        case 1:
            [self daemonDidRequestNewBackgroundSigning];
            break;
            
        case 2:
            [self daemonDidRequestCredentialsCheck];
            break;
            
        case 3:
            [self daemonDidRequestQueuedNotification];
            break;
            
        default:
            break;
    }
    
    // Reset the state so we don't redo anything when exiting the application.
    notify_set_state(_daemonNotificationToken, 0);
}

- (void)_notifyDaemonOfMessageHandled {
    // Let the daemon know to release the background assertion.
    notify_post("com.matchstic.reprovision.ios/didFinishBackgroundTask");
}

- (void)daemonDidRequestNewBackgroundSigning {
    // Start a background sign
    UIApplication *application = [UIApplication sharedApplication];
    UIBackgroundTaskIdentifier __block bgTask = [application beginBackgroundTaskWithName:@"ReProvision Background Signing" expirationHandler:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
        
        [self performSelector:@selector(_notifyDaemonOfMessageHandled) withObject:nil afterDelay:5];
    }];
    
    [[RPVBackgroundSigningManager sharedInstance] attemptBackgroundSigningIfNecessary:^{
        // Done, so stop this background task.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
        
        // Ask to remove our process assertion 5 seconds later, so that we can assume any notifications
        // have been scheduled.
        [self performSelector:@selector(_notifyDaemonOfMessageHandled) withObject:nil afterDelay:5];
    }];
}

- (void)daemonDidRequestCredentialsCheck {
    // Check that user credentials exist, notify if not
    if (![RPVResources getUsername] || [[RPVResources getUsername] isEqualToString:@""] || ![RPVResources getPassword] || [[RPVResources getPassword] isEqualToString:@""]) {
        
        [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"Login Required" body:@"Tap to login to ReProvision. This is needed to re-sign applications." isDebugMessage:NO isUrgentMessage:YES andNotificationID:@"login"];
    } else {
        // Nothing to do, just notify that we're done.
        [self _notifyDaemonOfMessageHandled];
    }
}

- (void)daemonDidRequestQueuedNotification {
    // Check if any applications need resigning. If they do, show notifications as appropriate.
    
    if ([[RPVBackgroundSigningManager sharedInstance] anyApplicationsNeedingResigning]) {
        [self _sendBackgroundedNotificationWithTitle:@"Re-signing Queued" body:@"Unlock your device to resign applications." isDebug:NO isUrgent:YES withNotificationID:@"resignQueued"];
    } else {
        [self _sendBackgroundedNotificationWithTitle:@"DEBUG" body:@"Background check has been queued for next unlock." isDebug:YES isUrgent:NO withNotificationID:nil];
    }
}

- (void)_sendBackgroundedNotificationWithTitle:(NSString*)title body:(NSString*)body isDebug:(BOOL)isDebug isUrgent:(BOOL)isUrgent withNotificationID:(NSString*)notifID {
    
    // We start a background task to ensure the notification is posted when expected.
    UIApplication *application = [UIApplication sharedApplication];
    UIBackgroundTaskIdentifier __block bgTask = [application beginBackgroundTaskWithName:@"ReProvision Background Notification" expirationHandler:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
        
        [self performSelector:@selector(_notifyDaemonOfMessageHandled) withObject:nil afterDelay:5];
    }];
    
    // Post the notification.
    [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:title body:body isDebugMessage:isDebug isUrgentMessage:isUrgent andNotificationID:notifID];
    
    // Done, so stop this background task.
    [application endBackgroundTask:bgTask];
    bgTask = UIBackgroundTaskInvalid;
    
    // Ask to remove our process assertion 5 seconds later, so that we can assume any notifications
    // have been scheduled.
    [self performSelector:@selector(_notifyDaemonOfMessageHandled) withObject:nil afterDelay:5];
}

@end
