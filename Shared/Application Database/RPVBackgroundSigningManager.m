//
//  RPVBackgroundSigningManager.m
//  iOS
//
//  Created by Matt Clarke on 26/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVBackgroundSigningManager.h"

#import "RPVApplicationSigning.h"
#import "RPVApplicationDatabase.h"
#import "RPVResources.h"
#import "RPVNotificationManager.h"

@interface RPVBackgroundSigningManager ()
@property (nonatomic, copy) void (^completionHandler)(void);
@end

@implementation RPVBackgroundSigningManager

+ (instancetype)sharedInstance {
    static RPVBackgroundSigningManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RPVBackgroundSigningManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        [[RPVApplicationSigning sharedInstance] addSigningUpdatesObserver:self];
    }
    
    return self;
}

- (void)attemptBackgroundSigningIfNecessary:(void (^)(void))completionHandler {
    if (![RPVResources shouldAutomaticallyResign]) {
        completionHandler();
        return;
    }
    
    self.completionHandler = completionHandler;
    
    [[RPVApplicationSigning sharedInstance] resignApplications:YES
                                        thresholdForExpiration:[RPVResources thresholdForResigning]
                                                    withTeamID:[RPVResources getTeamID]
                                                      username:[RPVResources getUsername]
                                                      password:[RPVResources getPassword]];
}

- (BOOL)anyApplicationsNeedingResigning {
    NSMutableArray *applications = [NSMutableArray array];
    NSDate *now = [NSDate date];
    NSDate *expirationDate = [now dateByAddingTimeInterval:60 * 60 * 24 * [RPVResources thresholdForResigning]];
    
    [[RPVApplicationDatabase sharedInstance] getApplicationsWithExpiryDateBefore:&applications andAfter:nil date:expirationDate forTeamID:[RPVResources getTeamID]];
    
    return applications.count > 0;
}

//////////////////////////////////////////////////////////////////////////////////
// Application Signing delegate methods.
//////////////////////////////////////////////////////////////////////////////////

- (void)applicationSigningDidStart {
    [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"DEBUG" body:@"Attempting background automatic signing" isDebugMessage:YES andNotificationID:nil];
}

- (void)applicationSigningUpdateProgress:(int)progress forBundleIdentifier:(NSString *)bundleIdentifier {}

- (void)applicationSigningDidEncounterError:(NSError *)error forBundleIdentifier:(NSString *)bundleIdentifier {}

- (void)applicationSigningCompleteWithError:(NSError *)error {
    if (self.completionHandler)
        self.completionHandler();
}

@end
