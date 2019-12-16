//
//  AuthKit.h
//  Provisioner
//
//  Created by Trung Nguyễn on 11/10/19.
//  Copyright © 2019 Trung Nguyễn. All rights reserved.
//
#import <UIKit/UIKit.h>
#ifndef AuthKit_h
#define AuthKit_h
@interface AKDevice : NSObject
+ (id)currentDevice;
- (NSString*)uniqueDeviceIdentifier;
- (NSString*)serverFriendlyDescription;
- (void)setServerFriendlyDescription:(NSString*)arg1;
@end

@interface AKAppleIDAuthenticationContext : NSObject
@property (copy) NSString *username;

- (id)init;
- (id)_initWithIdentifier:(id)arg1;
- (void)setAuthenticationType:(unsigned long long)arg1;
- (void)setTitle:(id)arg1;
- (void)setReason:(id)arg1;
- (void)setServiceIdentifier:(NSString*)arg1;
- (void)setServiceIdentifiers:(NSArray*)arg1;

- (void)_setPassword:(id)arg1;
- (void)setUsername:(id)arg1;

@end


@interface AKAppleIDAuthenticationController : NSObject

+ (id)sensitiveAuthenticationKeys;
- (id)_authenticationServiceConnection;
- (id)_urlBagFromCache:(BOOL)arg1 withError:(id *)arg2;
- (void)fetchURLBagWithCompletion:(id)arg1;
- (id)accountNamesForAltDSID:(id)arg1;
- (void)validateVettingToken:(id)arg1 forAltDSID:(id)arg2 completion:(id)arg3;
- (void)persistMasterKeyVerifier:(id)arg1 context:(id)arg2 completion:(id)arg3;
- (void)verifyMasterKey:(id)arg1 context:(id)arg2 completion:(id)arg3;
- (void)renewRecoveryTokenWithContext:(id)arg1 completion:(id)arg2;
- (void)teardownFollowUpWithContext:(id)arg1 completion:(id)arg2;
- (void)synchronizeFollowUpItemsForContext:(id)arg1 completion:(id)arg2;
- (BOOL)synchronizeFollowUpItemsForContext:(id)arg1 error:(id *)arg2;
- (void)getServerUILoadDelegateWithContext:(id)arg1 completion:(id)arg2;
- (void)getServerUILoadDelegateForAltDSID:(id)arg1 completion:(id)arg2;
- (id)activeLoginCode:(id *)arg1;
- (BOOL)isDevicePasscodeProtected:(id *)arg1;
- (void)updateStateWithExternalAuthenticationResponse:(id)arg1 forAppleID:(id)arg2 completion:(id)arg3;
- (void)updateStateWithExternalAuthenticationResponse:(id)arg1 forContext:(id)arg2 completion:(id)arg3;
- (void)reportSignOutForAllAppleIDsWithCompletion:(id)arg1;
- (void)reportSignOutForAppleID:(id)arg1 service:(long long)arg2 completion:(id)arg3;
- (void)checkInWithAuthenticationServerForAppleID:(id)arg1 completion:(id)arg2;
- (void)performCircleRequestWithContext:(id)arg1 completion:(id)arg2;
- (void)validateLoginCode:(unsigned long long)arg1 forAppleID:(id)arg2 completion:(id)arg3;
- (void)generateLoginCodeWithCompletion:(id)arg1;
- (void)checkSecurityUpgradeEligibilityForContext:(id)arg1 completion:(id)arg2;
- (void)configurationInfoWithIdentifiers:(id)arg1 forAltDSID:(id)arg2 completion:(id)arg3;
- (void)setConfigurationInfo:(id)arg1 forIdentifier:(id)arg2 forAltDSID:(id)arg3 completion:(id)arg4;
- (void)warmUpVerificationSessionWithCompletion:(id)arg1;
- (BOOL)revokeAuthorizationForApplicationWithClientID:(id)arg1 error:(id *)arg2;
- (BOOL)deleteAuthorizationDatabase:(id *)arg1;
- (id)fetchAuthorizedAppListWithContext:(id)arg1 error:(id *)arg2;
- (id)fetchPrimaryBundleIDForWebServiceWithInfo:(id)arg1 error:(id *)arg2;
- (id)fetchDeviceListWithContext:(id)arg1 error:(id *)arg2;
- (void)fetchDeviceMapWithContext:(id)arg1 completion:(id)arg2;
- (void)fetchDeviceListWithContext:(id)arg1 completion:(id)arg2;
- (void)fetchAuthModeWithContext:(id)arg1 completion:(id)arg2;
- (void)updateUserInformationForAltDSID:(id)arg1 userInformation:(id)arg2 completion:(id)arg3;
- (void)getUserInformationForAltDSID:(id)arg1 completion:(id)arg2;
- (void)fetchUserInformationForAltDSID:(id)arg1 completion:(id)arg2;
- (void)setAppleIDWithDSID:(id)arg1 inUse:(BOOL)arg2 forService:(long long)arg3;
- (void)setAppleIDWithAltDSID:(id)arg1 inUse:(BOOL)arg2 forService:(long long)arg3;
- (void)authenticateWithContext:(id)arg1 completion:(id)arg2;
- (id)initWithIdentifier:(id)arg1 daemonXPCEndpoint:(id)arg2;
- (id)initWithDaemonXPCEndpoint:(id)arg1;
- (id)initWithIdentifier:(id)arg1;
- (id)init;

@end

@interface AKAppleIDSession : NSObject
- (id)_pairedDeviceAnisetteController;
- (id)_nativeAnisetteController;
- (void)_handleURLResponse:(id)arg1 forRequest:(id)arg2 withCompletion:(id)arg3;
- (void)_generateAppleIDHeadersForSessionTask:(id)arg1 withCompletion:(id)arg2;
- (id)_generateAppleIDHeadersForRequest:(id)arg1 error:(id *)arg2;
- (id)_genericAppleIDHeadersDictionaryForRequest:(id)arg1;
- (void)handleResponse:(id)arg1 forRequest:(id)arg2 shouldRetry:(char *)arg3;
- (id)appleIDHeadersForRequest:(id)arg1;
- (void)URLSession:(id)arg1 task:(id)arg2 getAppleIDHeadersForResponse:(id)arg3 completionHandler:(id)arg4;
- (id)relevantHTTPStatusCodes;
- (id)copyWithZone:(struct _NSZone *)arg1;
- (void)encodeWithCoder:(id)arg1;
- (id)initWithCoder:(id)arg1;
- (id)initWithIdentifier:(id)arg1;
- (id)init;

@end
#endif /* AuthKit_h */
