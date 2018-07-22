//
//  RPVAccountChecker.m
//  iOS
//
//  Created by Matt Clarke on 07/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVAccountChecker.h"
#import "EEAppleServices.h"
#import "EEBackend.h"

#import <UIKit/UIKit.h>
#import "libMobileGestalt.h"

@implementation RPVAccountChecker

+ (instancetype)sharedInstance {
    static RPVAccountChecker *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RPVAccountChecker alloc] init];
    });
    return sharedInstance;
}

// Returns a failure reason, failure code, or team ID array
- (void)checkUsername:(NSString*)username withPassword:(NSString*)password andCompletionHandler:(void (^)(NSString*, NSString*, NSArray*))completionHandler {
    
    [EEAppleServices signInWithUsername:username password:password andCompletionHandler:^(NSError *error, NSDictionary *plist) {
        
        NSString *resultCode = [plist objectForKey:@"reason"];
        NSString *userString = [plist objectForKey:@"userString"];
        
        if ((!userString || [userString isEqualToString:@""]) && plist) {
            // Get Team ID array
            [EEAppleServices listTeamsWithCompletionHandler:^(NSError *error, NSDictionary *plist) {
                if (error) {
                    // oh shit.
                    completionHandler(error.localizedDescription, @"err", nil);
                    return;
                }
                
                NSArray *teams = [plist objectForKey:@"teams"];
                
                completionHandler(nil, resultCode, teams);
            }];
        } else if (plist) {
            completionHandler(userString, resultCode, nil);
        } else {
            completionHandler(userString, @"err", nil);
        }
    }];
}

- (NSString*)nameForCurrentDevice {
    return [[UIDevice currentDevice] name];
}

- (NSString*)UDIDForCurrentDevice {
    CFStringRef udid = (CFStringRef)MGCopyAnswer(kMGUniqueDeviceID);
    return (__bridge NSString*)udid;
}

- (void)registerCurrentDeviceForTeamID:(NSString*)teamID withUsername:(NSString*)username password:(NSString*)password andCompletionHandler:(void (^)(NSError*))completionHandler {
    
    [EEBackend provisionDevice:[self UDIDForCurrentDevice] name:[self nameForCurrentDevice] username:username password:password priorChosenTeamID:teamID withCallback:^(NSError *error) {
        completionHandler(error);
    }];
    
}

@end
