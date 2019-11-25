//
//  RPVResources.h
//  
//
//  Created by Matt Clarke on 09/01/2018.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define CURRENT_CREDENTIALS_VERSION @"1"

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
+ (NSTimeInterval)heartbeatTimerInterval;

+ (id)preferenceValueForKey:(NSString*)key;
+ (void)setPreferenceValue:(id)value forKey:(NSString*)key withNotification:(NSString*)notification;

/////////////////////////////////////////////////////////////////////////////////////////////////
// User Account
/////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString*)getUsername;
+ (NSString*)getPassword;
+ (NSString*)getTeamID;
+ (NSString*)getCredentialsVersion;
+ (void)storeUsername:(NSString*)username password:(NSString*)password andTeamID:(NSString*)teamId;

+ (void)userDidRequestAccountSignIn;
+ (void)userDidRequestAccountSignOut;

/////////////////////////////////////////////////////////////////////////////////////////////////
// Apple Watch
/////////////////////////////////////////////////////////////////////////////////////////////////

+ (BOOL)hasActivePairedWatch;
+ (NSString*)activePairedWatchUDID;
+ (NSString*)activePairedWatchName;

//////////////////////////////////////////////////////////////////////////////////
// Helper methods.
//////////////////////////////////////////////////////////////////////////////////

+ (NSString*)getFormattedTimeRemainingForExpirationDate:(NSDate*)expirationDate;
+ (CGRect)boundedRectForFont:(UIFont*)font andText:(NSString*)text width:(CGFloat)width;

@end
