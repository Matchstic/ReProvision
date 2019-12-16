//
//  EEAppleServices.h
//  Extender Installer
//
//  Created by Matt Clarke on 28/04/2017.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    EESystemTypeUndefined,
    EESystemTypeiOS,
    EESystemTypewatchOS,
    EESystemTypetvOS
} EESystemType;

@interface EEAppleServices : NSObject

+ (instancetype)sharedInstance;

/**
 * TODO: Docs!
 */
- (NSString*)currentTeamID;

- (void)ensureSessionWithIdentity:(NSString*)identity gsToken:(NSString*)token andCompletionHandler:(void (^)(NSError *error, NSDictionary *plist))completionHandler;

/**
 * TODO: Docs!
 */
- (void)signInWithUsername:(NSString*)email password:(NSString*)password andCompletionHandler:(void (^)(NSError*, NSDictionary*, NSURLCredential*))completionHandler;

- (void)requestTwoFactorLoginCodeWithCompletionHandler:(void (^)(NSError*))completion;

- (void)validateLoginCode:(NSString*)code andCompletionHandler:(void (^)(NSError*, NSDictionary*, NSURLCredential*))completionHandler;

- (void)fallback2FACodeRequest:(void(^)(NSError *, NSDictionary *, NSURLCredential *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)updateCurrentTeamIDWithTeamIDCheck:(NSString* (^)(NSArray*))teamIDCallback andCallback:(void (^)(NSError*, NSString *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)listTeamsWithCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)addDevice:(NSString*)udid deviceName:(NSString*)name forTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)listDevicesForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)listAllApplicationsForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)addApplicationId:(NSString*)applicationIdentifier name:(NSString*)applicationName enabledFeatures:(NSDictionary*)enabledFeatures teamID:(NSString*)teamID entitlements:(NSDictionary*)entitlements systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)updateApplicationIdId:(NSString*)appIdId enabledFeatures:(NSDictionary*)enabledFeatures teamID:(NSString*)teamID entitlements:(NSDictionary*)entitlements systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)deleteApplicationIdId:(NSString*)appIdId teamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)listAllApplicationGroupsForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)addApplicationGroupWithIdentifier:(NSString*)identifier andName:(NSString*)groupName forTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)assignApplicationGroup:(NSString*)applicationGroup toApplicationIdId:(NSString*)appIdId teamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)listAllDevelopmentCertificatesForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)viewDeveloperWithCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)listAllProvisioningProfilesForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)getProvisioningProfileForAppIdId:(NSString*)appIdId withTeamID:(NSString*)teamId systemType:(EESystemType)systemType andCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)deleteProvisioningProfileForApplication:(NSString*)applicationId andTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)revokeCertificateForSerialNumber:(NSString*)serialNumber andTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

/**
 * TODO: Docs!
 */
- (void)submitCodeSigningRequestForTeamID:(NSString*)teamId machineName:(NSString*)machineName machineID:(NSString*)machineID codeSigningRequest:(NSData*)csr systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler;

@end
