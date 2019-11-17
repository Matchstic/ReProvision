//
//  RPVAuthentication.m
//  iOS
//
//  Created by Matt Clarke on 11/11/2019.
//  Copyright © 2019 Matt Clarke. All rights reserved.
//

#import "RPVAuthentication.h"
#import "AuthKit.h"

@interface RPVAuthentication ()
@property (nonatomic, strong) AKAppleIDSession* appleIDSession;
@property (nonatomic, strong) AKAppleIDAuthenticationController* authenticationController;
@property (nonatomic, strong) AKAppleIDAuthenticationContext *currentContext;
@end

@implementation RPVAuthentication

- (void)_ensureAuthenticationController {
    if (!self.authenticationController) {
        AKAppleIDAuthenticationController *controller = [AKAppleIDAuthenticationController alloc];
        
        if ([controller respondsToSelector:@selector(initWithIdentifier:daemonXPCEndpoint:)])
            controller = [controller initWithIdentifier:nil daemonXPCEndpoint:nil];
        else
            controller = [controller initWithIdentifier:nil];
        
        self.authenticationController = controller;
    }
}

- (void)authenticateWithUsername:(NSString*)username password:(NSString*)password withCompletion:(void(^)(NSError *error, NSString *userIdentity, NSString *gsToken))completion {
    
    // Configure authentication context
    self.currentContext = [[AKAppleIDAuthenticationContext alloc] init];
    [self.currentContext setUsername:username];
    [self.currentContext _setPassword:password];
    
    if ([self.currentContext respondsToSelector:@selector(setAuthenticationType:)])
        [self.currentContext setAuthenticationType:2];
    
    [self.currentContext setServiceIdentifier:@"com.apple.gs.xcode.auth"];
    [self.currentContext setServiceIdentifiers:[NSArray arrayWithObject:@"com.apple.gs.xcode.auth"]];
    
    // Directly call into AuthKit for this context
    [self _ensureAuthenticationController];
    
    [self.authenticationController authenticateWithContext:self.currentContext completion:^(id result, id error) {
        NSLog(@"AUTHENTICATE WITH CONTEXT arg1: %@, arg2: %@", result, error);
        
        if (error) {
            completion(error, nil, nil);
            return;
        }
        
        NSString* AKUsername = [result objectForKey:@"AKUsername"];
        NSDictionary* IDMSToken = [result objectForKey:@"AKIDMSToken"];
        NSString* AKAltDSID = [result objectForKey:@"AKAltDSID"];
        
        NSString* GSToken = [IDMSToken objectForKey:@"com.apple.gs.xcode.auth"];
        NSString* username = [[NSString alloc] initWithFormat:@"%@|%@", AKAltDSID, AKUsername];
        
        completion(nil, username, GSToken);
    }];
}

- (void)validateLoginCode:(long long)code withCompletion:(void(^)(NSError *error, NSString *userIdentity, NSString *gsToken))completion {
    [self.authenticationController validateLoginCode:code forAppleID:self.currentContext.username completion:^(id result, id error) {
        NSLog(@"validateLoginCode arg1: %@, arg2: %@", result, error);
        
        if (error) {
            completion(error, nil, nil);
            return;
        }
        
        NSString* AKUsername = [result objectForKey:@"AKUsername"];
        NSDictionary* IDMSToken = [result objectForKey:@"AKIDMSToken"];
        NSString* AKAltDSID = [result objectForKey:@"AKAltDSID"];
        
        NSString* GSToken = [IDMSToken objectForKey:@"com.apple.gs.xcode.auth"];
        NSString* username = [[NSString alloc] initWithFormat:@"%@|%@", AKAltDSID, AKUsername];
        
        completion(nil, username, GSToken);
    }];
}

- (NSDictionary*)appleIDHeadersForRequest:(NSURLRequest*)request {
    if (!self.appleIDSession){
        self.appleIDSession = [[AKAppleIDSession alloc] initWithIdentifier:@"com.apple.gs.xcode.auth"];
    }
    
    return [self.appleIDSession appleIDHeadersForRequest:request];
}

@end
