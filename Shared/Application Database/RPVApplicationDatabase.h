//
//  RPVApplicationDatabase.h
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RPVApplication;

@interface RPVApplicationDatabase : NSObject

/**
 Gives a shared instance of RPVApplicationDatabase
 */
+ (instancetype)sharedInstance;

/**
 Gives all applications on the local devcie that have been provisioned with the provided Team ID.
 @return An array of RPVApplication
 */
- (NSArray*)getAllApplicationsForTeamID:(NSString*)teamID;

/**
 Creates a new RPVApplication object for the given bundle identifier.
 @param bundleIdentifier Bundle identifier of the application
 @return New abstract object for the application.
 */
- (RPVApplication*)getApplicationWithBundleIdentifier:(NSString*)bundleIdentifier;

/**
 beforeApplications will end up containing all applications that expire before the given date, and
 afterApplications has those expiring after the given date.
 
 Therefore, any applications expiring soon are those that have an expiry date before the cutoff, e.g.
 a cutoff of NSDate(today + 2 days) gives all applications expiring in the next two days.
 
 @param beforeApplications A mutable array of applications, filled by those who expire before the cutoff date
 @param afterApplications A mutable array of applications, filled by those who expire after the cutoff date. This may be nil.
 @param cutoffDate The date that separates applications
 @param teamID The Team ID associated with the user's sideloaded applications.
 @return Success indicator
 */
- (BOOL)getApplicationsWithExpiryDateBefore:(NSMutableArray**)beforeApplications andAfter:(NSMutableArray**)afterApplications date:(NSDate*)cutoffDate forTeamID:(NSString*)teamID;

- (NSArray*)getAllSideloadedApplicationsNotMatchingTeamID:(NSString*)teamID;

@end
