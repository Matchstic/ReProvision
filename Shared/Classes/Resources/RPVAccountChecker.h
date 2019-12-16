//
//  RPVAccountChecker.h
//  iOS
//
//  Created by Matt Clarke on 07/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface RPVAccountChecker : NSObject

+ (instancetype)sharedInstance;

- (void)checkUsername:(NSString*)username withPassword:(NSString*)password andCompletionHandler:(void (^)(NSString*, NSString*, NSArray*, NSURLCredential*))completionHandler;

- (void)requestLoginCodeWithCompletionHandler:(void (^)(NSError *error))completion;

- (void)request2FAFallbackWithCompletionHandler:(void (^)(NSString*, NSString*, NSArray*, NSURLCredential*))completionHandler;

- (void)validateLoginCode:(NSString*)code withCompletionHandler:(void (^)(NSString*, NSString*, NSArray*, NSURLCredential*))completionHandler;

- (void)registerCurrentDeviceForTeamID:(NSString*)teamID withIdentity:(NSString*)username gsToken:(NSString*)password andCompletionHandler:(void (^)(NSError*))completionHandler;

- (void)registerCurrentWatchForTeamID:(NSString*)teamID withIdentity:(NSString*)username gsToken:(NSString*)password andCompletionHandler:(void (^)(NSError*))completionHandler;

@end
