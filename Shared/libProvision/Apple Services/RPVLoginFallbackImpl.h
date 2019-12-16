//
//  RPVLoginFallbackImpl.h
//  iOS
//
//  Created by Matt Clarke on 14/12/2019.
//  Copyright © 2019 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^RPVLoginFallbackResultBlock)(NSError *error, NSString *userIdentity, NSString *gsToken);

@interface RPVLoginFallbackImpl : NSObject

- (instancetype)initWithClientInfoOverride:(NSString*)clientInfoOverride;

- (void)loginWithUsername:(NSString*)username password:(NSString*)password completion:(RPVLoginFallbackResultBlock)completionHandler;

@end
