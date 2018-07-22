//
//  RPVNotificationManager.m
//  iOS
//
//  Created by Matt Clarke on 26/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>

#import "RPVNotificationManager.h"
#import "RPVResources.h"
#import "HookUtil.h"

#import <RMessage.h>

// Fix for crashing when using stashing.
HOOK_MESSAGE(id, UNUserNotificationCenter, initWithBundleIdentifier_, NSString *bundleID) {
    NSLog(@"*** [ReProvision] :: Hooked -[UNUserNotificationCenter initWithBundleIdentifier:]");
    
    id result;
    
    if (!bundleID) {
        bundleID = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    @try {
        result = _UNUserNotificationCenter_initWithBundleIdentifier_(self, sel, bundleID);
    } @catch (NSException *e) {
        result = _UNUserNotificationCenter_initWithBundleIdentifier_(self, sel, [[NSBundle mainBundle] bundleIdentifier]);
    }
    
    return result;
}

@implementation RPVNotificationManager

+ (instancetype)sharedInstance {
    static RPVNotificationManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RPVNotificationManager alloc] init];
        
        // Setup iOS 9 stylings
        [RMessage addDesignsFromFileWithName:@"RMessageDesign" inBundle:[NSBundle mainBundle]];
    });
    return sharedInstance;
}

- (double)_systemVersion {
    return [[UIDevice currentDevice] systemVersion].floatValue;
}

- (void)registerToSendNotifications {
    
    if (@available(iOS 10.0, *)) {
        // For responding to notifications.
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
        
        // And requesting of authorisation
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert) completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (error) {
                // Failure to register for notifications.
                NSLog(@"***** Error: %@", error.localizedDescription);
            } else if (!granted) {
                NSLog(@"***** Notification authorization was not granted.");
            }
        }];
    } else {
        // TODO: Is this correct for local notifications on iOS 9?
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            [[UIApplication sharedApplication] registerUserNotificationSettings:[objc_getClass("UIUserNotificationSettings") settingsForTypes:7 categories:nil]];
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        }
    }
}

- (void)sendNotificationWithTitle:(NSString*)title body:(NSString*)body isDebugMessage:(BOOL)isDebug andNotificationID:(NSString*)identifier {
    [self sendNotificationWithTitle:title body:body isDebugMessage:isDebug isUrgentMessage:NO andNotificationID:identifier];
}

- (void)sendNotificationWithTitle:(NSString*)title body:(NSString*)body isDebugMessage:(BOOL)isDebug isUrgentMessage:(BOOL)isUrgent andNotificationID:(NSString*)identifier {
    if (isDebug && ![RPVResources shouldShowDebugAlerts]) {
        return;
    }
    
    if (!isUrgent && ![RPVResources shouldShowNonUrgentAlerts]) {
        return;
    }
    
    // Allow identifier to be optional
    if (!identifier)
        identifier = [NSString stringWithFormat:@"notif_%f", [[NSDate date] timeIntervalSince1970]];
    
    if ([self _systemVersion] < 10.0) {
        [self _oldSendNotificationWithTitle:title body:body andNotificationID:identifier];
    } else {
        [self _newSendNotificationWithTitle:title body:body andNotificationID:identifier];
    }
}

- (void)_oldSendNotificationWithTitle:(NSString*)title body:(NSString*)body andNotificationID:(NSString*)identifier {
    // Local notification sending for iOS 9
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:1];
    notification.timeZone = [NSTimeZone systemTimeZone];
    notification.alertBody = body;
    notification.alertTitle = title;
    notification.soundName = nil;
    
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
    
    // Send one in-app also.
    // Cancel any existing notification.
    [RMessage dismissActiveNotification];
    [RMessage showNotificationWithTitle:title
                               subtitle:body
                              iconImage:nil
                                   type:RMessageTypeNormal
                         customTypeName:@"ios9"
                               duration:3.0
                               callback:nil
                            buttonTitle:nil
                         buttonCallback:nil
                             atPosition:RMessagePositionTop
                   canBeDismissedByUser:YES];
}

- (void)_newSendNotificationWithTitle:(NSString*)title body:(NSString*)body andNotificationID:(NSString*)identifier {
    // UserNotifications
    
    // Silence compiler warnings
    if (@available(iOS 10.0, *)) {
        UNMutableNotificationContent *objNotificationContent = [[UNMutableNotificationContent alloc] init];
        
        objNotificationContent.title = title;
        objNotificationContent.body = body;
        objNotificationContent.sound = nil;
        
        // Update application icon badge number if applicable
        //objNotificationContent.badge = @([[UIApplication sharedApplication] applicationIconBadgeNumber]);
        
        // Set time of notification being triggered
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];
        
        UNNotificationRequest *request = [UNNotificationRequest
                                          requestWithIdentifier:identifier                                                                   content:objNotificationContent trigger:trigger];
        
        // Schedule localNotification
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error: %@", error.localizedDescription);
            }
            
        }];
    }
}

//////////////////////////////////////////////////////////////////////////////////////
// UNUserNotificationCenterDelegate
//////////////////////////////////////////////////////////////////////////////////////

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler NS_AVAILABLE_IOS(10_0) {
    
    NSString *identifier = response.notification.request.identifier;
    
    if ([identifier isEqualToString:@"login"]) {
        // TODO: Present login UI?
        
    }
    
    completionHandler();
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler NS_AVAILABLE_IOS(10_0) {
    // Ensure that alerts will display in-app.
    completionHandler(UNNotificationPresentationOptionAlert);
}

@end
