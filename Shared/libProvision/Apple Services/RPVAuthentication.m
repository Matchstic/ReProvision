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
@end

@implementation RPVAuthentication

- (void)authenticateWithUsername:(NSString*)username password:(NSString*)password withCompletion:(void(^)(NSError *error, NSString *userIdentity, NSString *gsToken))completion {
    
    // Configure authentication context
    AKAppleIDAuthenticationInAppContext* context = [[AKAppleIDAuthenticationInAppContext alloc] init];
    [context setUsername:username];
    [context _setPassword:password];
    
    [context setAuthenticationType:2];
    [context setServiceIdentifier:@"com.apple.gs.xcode.auth"];
    [context setServiceIdentifiers:[NSArray arrayWithObject:@"com.apple.gs.xcode.auth"]];
    
    // Directly call into AuthKit for this context
    AKAppleIDAuthenticationController* controller = [[AKAppleIDAuthenticationController alloc] initWithIdentifier:nil daemonXPCEndpoint:nil];
    
    [controller authenticateWithContext:context completion:^(id arg1) {
        if (!arg1) {
            completion([NSError errorWithDomain:NSURLErrorDomain code:-1 userInfo:nil], nil, nil);
            return;
        }
        
        NSLog(@"AUTHENTICATED WITH: %@", arg1);
        
        NSString* AKUsername = [arg1 objectForKey:@"AKUsername"];
        NSDictionary* IDMSToken = [arg1 objectForKey:@"AKIDMSToken"];
        NSString* AKAltDSID = [arg1 objectForKey:@"AKAltDSID"];
        
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
