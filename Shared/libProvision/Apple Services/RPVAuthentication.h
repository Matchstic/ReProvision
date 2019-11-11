//
//  RPVAuthentication.h
//  iOS
//
//  Created by Matt Clarke on 11/11/2019.
//  Copyright © 2019 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RPVAuthentication : NSObject

/**
 * Authenticates against gsa.apple.com with the given username and password
 */
- (void)authenticateWithUsername:(NSString*)username password:(NSString*)password withCompletion:(void(^)(NSError *error, NSString *userIdentity, NSString *gsToken))completion;

- (NSDictionary*)appleIDHeadersForRequest:(NSURLRequest*)request;

@end
