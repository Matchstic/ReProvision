//
//  RPVNotificationManager.h
//  iOS
//
//  Created by Matt Clarke on 26/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

@interface RPVNotificationManager : NSObject <UNUserNotificationCenterDelegate>

+ (instancetype)sharedInstance;

- (void)registerToSendNotifications;

- (void)sendNotificationWithTitle:(NSString*)title body:(NSString*)body isDebugMessage:(BOOL)isDebug isUrgentMessage:(BOOL)isUrgent andNotificationID:(NSString*)identifier;
- (void)sendNotificationWithTitle:(NSString*)title body:(NSString*)body isDebugMessage:(BOOL)isDebug andNotificationID:(NSString*)identifier;

@end
