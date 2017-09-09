//
//  EEAppleServices.h
//  Extender Installer
//
//  Created by Matt Clarke on 28/04/2017.
//
//

#import <Foundation/Foundation.h>

@interface EEAppleServices : NSObject

+ (void)signInWithUsername:(NSString*)username password:(NSString*)password andCompletionHandler:(void (^)(NSError*, NSDictionary*))completionHandler;

+ (void)listTeamsWithCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

+ (void)listAllApplicationsForTeamID:(NSString*)teamID withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

+ (void)listAllDevelopmentCertificatesForTeamID:(NSString*)teamID withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

+ (void)listAllProvisioningProfilesForTeamID:(NSString*)teamID withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;
+ (void)deleteProvisioningProfileForApplication:(NSString*)applicationId andTeamID:(NSString*)teamID withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

+ (void)revokeCertificateForSerialNumber:(NSString*)serialNumber andTeamID:(NSString*)teamID withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

@end
