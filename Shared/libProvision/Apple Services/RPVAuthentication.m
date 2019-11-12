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
    AKAppleIDAuthenticationContext* context = [[AKAppleIDAuthenticationContext alloc] init];
    [context setUsername:username];
    [context _setPassword:password];
    
    if ([context respondsToSelector:@selector(setAuthenticationType:)])
        [context setAuthenticationType:2];
    
    [context setServiceIdentifier:@"com.apple.gs.xcode.auth"];
    [context setServiceIdentifiers:[NSArray arrayWithObject:@"com.apple.gs.xcode.auth"]];
    
    // Directly call into AuthKit for this context
    AKAppleIDAuthenticationController* controller = [[AKAppleIDAuthenticationController alloc] initWithIdentifier:nil daemonXPCEndpoint:nil];
    
    [controller authenticateWithContext:context completion:^(id result, id error) {
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

- (NSDictionary*)appleIDHeadersForRequest:(NSURLRequest*)request {
    if (!self.appleIDSession){
        self.appleIDSession = [[AKAppleIDSession alloc] initWithIdentifier:@"com.apple.gs.xcode.auth"];
    }
    
    return [self.appleIDSession appleIDHeadersForRequest:request];
}

@end
