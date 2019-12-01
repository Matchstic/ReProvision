//
//  RPVAuthentication.m
//  iOS
//
//  Created by Matt Clarke on 11/11/2019.
//  Copyright © 2019 Matt Clarke. All rights reserved.
//

#import "RPVAuthentication.h"
#import "AuthKit.h"
#include "RPVLoginImpl.h"

@interface RPVAuthentication ()

@property (nonatomic, strong) AKAppleIDSession* appleIDSession;
@property (nonatomic, strong) RPVLoginImpl *loginImpl;

@property (nonatomic, strong) NSString *cachedIdmsTokenFor2FA;
@property (nonatomic, strong) NSString *cachedUserIdentityFor2FA;
@property (nonatomic, strong) NSString *cachedUserPasswordFor2FA;
@property (nonatomic, readwrite) int requested2FAMode;

@end

@implementation RPVAuthentication

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.loginImpl = [[RPVLoginImpl alloc] init];
    }
    
    return self;
}

- (void)authenticateWithUsername:(NSString*)username password:(NSString*)password withCompletion:(void(^)(NSError *error, NSString *userIdentity, NSString *gsToken))completion {
    
    // Reset cached data for 2FA
    self.cachedUserIdentityFor2FA = nil;
    self.cachedIdmsTokenFor2FA = nil;
    self.cachedUserPasswordFor2FA = nil;
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        // Ensure username is lowercase!
        [self.loginImpl loginWithUsername:[username lowercaseString]
                                 password:password completion:^(NSError *error, NSString *userIdentity, NSString *gsToken, NSString *idmsToken) {
            if (error.code == RPVInternalLogin2FARequiredSecondaryAuthError ||
                error.code == RPVInternalLogin2FARequiredTrustedDeviceError) {
                self.cachedIdmsTokenFor2FA = idmsToken;
                self.cachedUserIdentityFor2FA = userIdentity;
                self.cachedUserPasswordFor2FA = password;
                self.requested2FAMode = error.code;
            }
            
            completion(error, userIdentity, gsToken);
        }];
    });
}

- (void)requestLoginCodeWithCompletion:(void(^)(NSError*))completionHandler {
    [self.loginImpl requestTwoFactorCodeWithUserIdentity:self.cachedUserIdentityFor2FA
                                       idmsToken:self.cachedIdmsTokenFor2FA
                                        mode:self.requested2FAMode
                                   andCompletion:completionHandler];
}

- (void)validateLoginCode:(long long)code withCompletion:(void(^)(NSError *error, NSString *userIdentity, NSString *gsToken))completion {
    
    // First, validate the code.
    [self.loginImpl submitTwoFactorCode:[NSString stringWithFormat:@"%llu", code]
                       withUserIdentity:self.cachedUserIdentityFor2FA
                              idmsToken:self.cachedIdmsTokenFor2FA
                          andCompletion:^(NSError *error) {
        if (error) {
            completion(error, nil, nil);
        } else {
            // Success, re-login again to get the GS Token
            NSString *username = [self.cachedUserIdentityFor2FA componentsSeparatedByString:@"|"].lastObject;
            [self authenticateWithUsername:username
                                  password:self.cachedUserPasswordFor2FA
                            withCompletion:^(NSError *error, NSString *userIdentity, NSString *gsToken) {
                
                // Clear cache if needed
                if (!error) {
                    self.cachedUserIdentityFor2FA = nil;
                    self.cachedIdmsTokenFor2FA = nil;
                    self.cachedUserPasswordFor2FA = nil;
                }
                
                completion(error, userIdentity, gsToken);
            }];
        }
    }];
}

- (NSDictionary*)appleIDHeadersForRequest:(NSURLRequest*)request {
    if (!self.appleIDSession){
        self.appleIDSession = [[AKAppleIDSession alloc] initWithIdentifier:@"com.apple.gs.xcode.auth"];
    }
    
    NSMutableDictionary *result = [[self.appleIDSession appleIDHeadersForRequest:request] mutableCopy];
    
    // Override some auth parameters
    [result setObject:@"com.apple.gs.xcode.auth" forKey:@"X-Apple-App-Info"];
    [result setObject:self.loginImpl.clientInfoOverride forKey:@"X-MMe-Client-Info"];
    
    return result;
}

@end
