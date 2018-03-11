//
//  RPVResources.h
//  
//
//  Created by Matt Clarke on 09/01/2018.
//

#import <Foundation/Foundation.h>

@interface RPVResources : NSObject

/////////////////////////////////////////////////////////////////////////////////////////////////
// User Settings
/////////////////////////////////////////////////////////////////////////////////////////////////

+ (BOOL)shouldShowDebugAlerts;
+ (BOOL)shouldShowAlerts;
+ (BOOL)shouldShowNonUrgentAlerts;
+ (int)thresholdForResigning;
+ (BOOL)shouldAutomaticallyResign;
+ (BOOL)shouldResignInLowPowerMode;
+ (BOOL)shouldAutoRevokeIfNeeded;

+ (id)preferenceValueForKey:(NSString*)key;
+ (void)setPreferenceValue:(id)value forKey:(NSString*)key withNotification:(NSString*)notification;

/////////////////////////////////////////////////////////////////////////////////////////////////
// User Account
/////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString*)getUsername;
+ (NSString*)getPassword;
+ (NSString*)getTeamID;
+ (void)storeUsername:(NSString*)username password:(NSString*)password andTeamID:(NSString*)teamId;

+ (void)userDidRequestAccountSignIn;
+ (void)userDidRequestAccountSignOut;

@end
