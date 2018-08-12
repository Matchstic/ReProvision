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

@implementation RPVNotificationManager

+ (instancetype)sharedInstance {
    static RPVNotificationManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RPVNotificationManager alloc] init];
    });
    return sharedInstance;
}

- (void)registerToSendNotifications {
    // TODO: Setup in-app notifications library
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
    
    // TODO: Display notification via in-app library
}

- (void)_updateBadge {
    
    // Silence compiler warnings
    if (@available(tvOS 10.0, *)) {
        UNMutableNotificationContent *objNotificationContent = [[UNMutableNotificationContent alloc] init];
        
        objNotificationContent.badge = @1;
        
        // Update application icon badge number if applicable
        //objNotificationContent.badge = @([[UIApplication sharedApplication] applicationIconBadgeNumber]);
        
        // Set time of notification being triggered
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];

        NSString *identifier = [NSString stringWithFormat:@"notif_%f", [[NSDate date] timeIntervalSince1970]];
        
        UNNotificationRequest *request = [UNNotificationRequest
                                          requestWithIdentifier:identifier                                                                content:objNotificationContent trigger:trigger];
        
        // Schedule localNotification
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error: %@", error.localizedDescription);
            }
            
        }];
    }
}

@end
