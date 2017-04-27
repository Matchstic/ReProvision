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
+ (BOOL)shouldAutoSign;
+ (int)thresholdForResigning;

+ (NSString*)username;
+ (NSString*)password;
+ (void)storeUsername:(NSString*)username andPassword:(NSString*)password;
+ (void)signOut;
+ (void)signInWithCallback:(void (^)(BOOL))completionHandler;

+ (NSDictionary *)provisioningProfileAtPath:(NSString *)path;
+ (BOOL)attemptToRevokeCertificate;

+ (void)reloadSettings;

@end
