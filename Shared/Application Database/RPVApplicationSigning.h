//
//  RPVApplicationSigning.h
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RPVErrors.h"

@interface RPVApplicationSigning : NSObject

+ (instancetype)sharedInstance;

/**
 Call to start resigning applications. It is *highly* recommended to do so within a background task.
 
 Make sure to undertake checks such as if the user is in Low Power Mode etc BEFORE calling. Only network connectivity is checked here.
 
 @param onlyExpiringApplications If NO, then all applications associated with the user's Team ID will be re-signed.
 @param thresholdForExpiration Specified in days from expiration, this adjusts the threshold for when an application is considered to be close to expiration.
 @param teamID The user's Team ID to generate a list of on-device applications that are applicable to be re-signed.
 @param username The user's username to authenticate with Apple's Developer Portal
 @param password The user's password to authenticate with Apple's Developer Portal
 @param progressUpdateHandler Called when progress is made on the re-signing pipeline for a given bundle identifier. arg0 is the bundle identifier, and arg1 is the progress in percent (0-100)
 @param errorHandler Called when an error occurs for a single application's pipeline.
 @param completionHandler Called when the pipeline is finished for all applications.
 */
- (void)resignApplications:(BOOL)onlyExpiringApplications thresholdForExpiration:(int)thresholdForExpiration withTeamID:(NSString*)teamID username:(NSString*)username password:(NSString*)password progressUpdateHandler:(void (^)(NSString*, int))progressUpdateHandler errorHandler:(void (^)(NSError*, NSString*))errorHandler andCompletionHandler:(void (^)(NSError*))completionHandler;

@end
