//
//  EEProvisioning.h
//  OpenExtenderTest
//
//  Created by Matt Clarke on 28/12/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EEAppleServices.h"

@interface EEProvisioning : NSObject {
    NSString *_identity;
    NSString *_gsToken;
}

/**
 Creates a new instance of EEProvisioning with the given credentials.
 Note: if using 2-Factor Authentication, make sure to generate an App-Specific password
 
 @param identity The DSIS identity to sign in to Apple developer with.
 @param gsToken The GS token associated with the identity.
 */
+ (instancetype)provisionerWithCredentials:(NSString*)identity :(NSString*)gsToken;

/**
 Adds the current device to Apple's Developer portal for the current team. It is likely this should only need
 to be called once, such as when validating user credentials.
 
 @param completionHandler The block called once the operation is complete.
 
 In the completionHandler, the first value is a success indicator. The second is the result; if success is NO,
 then this shall be the associated error message.
 */
- (void)provisionDevice:(NSString*)udid name:(NSString*)name withTeamIDCheck:(NSString* (^)(NSArray*))teamIDCallback systemType:(EESystemType)systemType  andCallback:(void (^)(NSError*))completionHandler;

/** TODO: Docs!
 */
- (void)revokeCertificatesWithTeamIDCheck:(NSString* (^)(NSArray*))teamIDCallback systemType:(EESystemType)systemType andCallback:(void (^)(NSError*))completionHandler;

/**
 Does all the hard work behind-the-scenes work to download a provisioning profile for a given application.
 
 @param identifier The bundle identifier of the application to provision.
 @param completionHandler The block called once the provisioning profile is downloaded.
 
 In the completionHandler, the first value is a success indicator. The second is the result; if success is NO,
 then this shall be the associated error message. If YES, then it is the profile, and the third is the development
 certificate to sign binaries with.
 */
- (void)downloadProvisioningProfileForApplicationIdentifier:(NSString*)identifier binaryLocation:(NSString*)binaryLocation withTeamIDCheck:(NSString* (^)(NSArray*))teamIDCallback systemType:(EESystemType)systemType andCallback:(void (^)(NSError *, NSData*, NSString*, NSDictionary*, NSDictionary*))completionHandler;

@end
