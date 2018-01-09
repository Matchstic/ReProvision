//
//  EEResources.h
//  Extender Installer
//
//  Created by Matt Clarke on 20/04/2017.
//
//

#import <Foundation/Foundation.h>

@interface EEResources : NSObject

+ (BOOL)shouldShowDebugAlerts;
+ (BOOL)shouldShowAlerts;
+ (BOOL)shouldShowNonUrgentAlerts;
+ (int)thresholdForResigning;
+ (BOOL)shouldAutomaticallyResign;
+ (BOOL)shouldResignInLowPowerMode;
+ (BOOL)shouldAutoRevokeIfNeeded;

+ (NSTimeInterval)heartbeatTimerInterval;
+ (void)reloadHeartbeatTimer;

+ (NSString*)username;
+ (NSString*)password;
+ (NSString*)getTeamID;
+ (void)storeUsername:(NSString*)username andPassword:(NSString*)password;
+ (void)signOut;
+ (void)signInWithCallback:(void (^)(BOOL, NSString*))completionHandler;

+ (NSDictionary *)provisioningProfileAtPath:(NSString *)path;
+ (void)removeExistingProvisioningProfileForApplication:(NSString*)bundleIdentifier withCallback:(void (^)(BOOL))completionHandler;
+ (void)attemptToRevokeCertificateWithCallback:(void (^)(BOOL))completionHandler;
+ (void)_actuallyRevokeCertificatesWithAlert:(id)controller andCallback:(void (^)(BOOL))completionHandler;

+ (void)cleanupExpiredProvisioningCertificatesWithCompletionHandler:(void(^)(BOOL))completionHandler;

+ (void)reloadSettings;

@end
