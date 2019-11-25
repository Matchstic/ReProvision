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
@property (nonatomic, strong) AKAppleIDAuthenticationContext *currentContext;
@end

@implementation RPVAuthentication

- (void)authenticateWithUsername:(NSString*)username password:(NSString*)password withCompletion:(void(^)(NSError *error, NSString *userIdentity, NSString *gsToken))completion {
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        perform_login(username, password, completion);
    });
}

- (void)validateLoginCode:(long long)code withCompletion:(void(^)(NSError *error, NSString *userIdentity, NSString *gsToken))completion {
    // Not yet implemented
    completion(nil, @"", @"");
}

- (NSDictionary*)appleIDHeadersForRequest:(NSURLRequest*)request {
    if (!self.appleIDSession){
        self.appleIDSession = [[AKAppleIDSession alloc] initWithIdentifier:@"com.apple.gs.xcode.auth"];
    }
    
    NSMutableDictionary *result = [[self.appleIDSession appleIDHeadersForRequest:request] mutableCopy];
    
    // Override some auth parameters
    [result setObject:@"com.apple.gs.xcode.auth" forKey:@"X-Apple-App-Info"];
    [result setObject:@"<MacBookPro11,5> <Mac OS X;10.14.6;18G103> <com.apple.AuthKit/1 (com.apple.akd/1.0)>" forKey:@"X-MMe-Client-Info"];
    
    return result;
}

@end
