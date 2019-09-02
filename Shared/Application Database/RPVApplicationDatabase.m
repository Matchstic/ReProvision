//
//  RPVApplicationDatabase.m
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVApplicationDatabase.h"
#import "RPVApplication.h"

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *teamID;
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSURL *bundleURL;
@property (nonatomic, readonly) BOOL isAdHocCodeSigned;
+ (instancetype)applicationProxyForIdentifier:(NSString*)arg1;
@end

@interface LSApplicationWorkspace : NSObject
+(instancetype)defaultWorkspace;
-(BOOL)installApplication:(NSURL*)arg1 withOptions:(NSDictionary*)arg2 error:(NSError**)arg3;
- (NSArray*)allApplications;
@end

@interface RPVApplicationDatabase ()

@end

static RPVApplicationDatabase *sharedDatabase;

@implementation RPVApplicationDatabase

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        sharedDatabase = [[self alloc] init];
    });
    
    return sharedDatabase;
}

/**
 * Gives an array of RPVApplication that have the same Team ID as passed to this method.
 */
- (NSArray *)_retrieveAllApplicationsForTeamID:(NSString*)teamID {
    if (!teamID || [teamID isEqualToString:@""]) {
        return [NSArray array];
    }
    
    NSMutableArray *applications = [NSMutableArray array];
    
    for (LSApplicationProxy *proxy in [[LSApplicationWorkspace defaultWorkspace] allApplications]) {
        // If the teamID doesn't match, ignore.
        // If the bundleURL is /Application/*, then ignore.
        if ([[proxy teamID] isEqualToString:teamID] && ![[proxy.bundleURL path] hasPrefix:@"/Application"]) {
            RPVApplication *application = [[RPVApplication alloc] initWithApplicationProxy:proxy];
            
            [applications addObject:application];
        }
    }
    
    return applications;
}

- (NSArray*)getAllApplicationsForTeamID:(NSString*)teamID {
    return [self _retrieveAllApplicationsForTeamID:teamID];
}

- (RPVApplication*)getApplicationWithBundleIdentifier:(NSString*)bundleIdentifier {
    LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:bundleIdentifier];
    return [[RPVApplication alloc] initWithApplicationProxy:proxy];
}

- (NSArray*)getAllSideloadedApplicationsNotMatchingTeamID:(NSString*)teamID {
    NSMutableArray *applications = [NSMutableArray array];
    
    // Parse the currently installed profiles.
    // If the profile has a non-matching Team ID, perfect.
    
    for (LSApplicationProxy *proxy in [[LSApplicationWorkspace defaultWorkspace] allApplications]) {
        if (![[proxy teamID] isEqualToString:@"0000000000"]) {
            // First sanity check passed for system apps, check for embedded profile.
            
            NSString *provisionPath = [[proxy.bundleURL path] stringByAppendingString:@"/embedded.mobileprovision"];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:provisionPath]) {
                // Yep, definitely sideloaded!
                
                NSDictionary *plist = [RPVApplication provisioningProfileAtPath:provisionPath];
                    
                // Check Team ID.
                NSString *teamIDToCheck = [[plist objectForKey:@"TeamIdentifier"] firstObject];
                
                if (![teamIDToCheck isEqualToString:teamID]) {
                    // Success!
                    RPVApplication *application = [[RPVApplication alloc] initWithApplicationProxy:proxy];
                    
                    [applications addObject:application];
                }
            }
        }
    }
    
    return applications;
}

/**
 beforeApplications will end up containing all applications that expire before the given date, and
 afterApplications has those expiring after the given date.
 
 Therefore, any applications expiring soon are those that have an expiry date before the cutoff, e.g.
 a cutoff of NSDate(today + 2 days) gives all applications expiring in the next two days.
 */
- (BOOL)getApplicationsWithExpiryDateBefore:(NSMutableArray**)beforeApplications andAfter:(NSMutableArray**)afterApplications date:(NSDate*)cutoffDate forTeamID:(NSString*)teamID {
    
    NSArray *applications = [self _retrieveAllApplicationsForTeamID:teamID];
    
    for (RPVApplication *application in applications) {
        NSDate *expiryDate = [application applicationExpiryDate];
        
        if ([expiryDate compare:cutoffDate] == NSOrderedAscending && beforeApplications) {
            // expiry date is before the cutoff date.
            [*beforeApplications addObject:application];
        } else if (afterApplications) {
            [*afterApplications addObject:application];
        }
    }
    
    return YES;
}

@end
