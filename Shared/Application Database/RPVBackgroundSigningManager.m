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

#include <notify.h>

#if __cplusplus
extern "C" {
#endif
    // BackBoardServices

    #define BKSProcessAssertionFlagNone 0
    #define BKSProcessAssertionFlagPreventSuspend (1 << 0)
    #define BKSProcessAssertionFlagPreventThrottleDownCPU (1 << 1)
    #define BKSProcessAssertionFlagAllowIdleSleep (1 << 2)
    #define BKSProcessAssertionFlagWantsForegroundResourcePriority (1 << 3)

    typedef enum {
        BKSProcessAssertionReasonNone,
        BKSProcessAssertionReasonAudio,
        BKSProcessAssertionReasonLocation,
        BKSProcessAssertionReasonExternalAccessory,
        BKSProcessAssertionReasonFinishTask,
        BKSProcessAssertionReasonBluetooth,
        BKSProcessAssertionReasonNetworkAuthentication,
        BKSProcessAssertionReasonBackgroundUI,
        BKSProcessAssertionReasonInterAppAudioStreaming,
        BKSProcessAssertionReasonViewServices
    } BKSProcessAssertionReason;
#if __cplusplus
}
#endif

@interface BKSProcessAssertion : NSObject
- (id)initWithPID:(pid_t)arg1 flags:(unsigned int)arg2 reason:(BKSProcessAssertionReason)arg3 name:(NSString*)arg4 withHandler:(void (^)(BOOL success))arg5;
- (void)invalidate;
@end

@interface RPVBackgroundSigningManager ()
@property (nonatomic, copy) void (^completionHandler)(void);

@property (nonatomic, strong) NSTimer *signingTimer;
@property (nonatomic, readwrite) BOOL updateQueuedForUnlock;
@property (nonatomic, readwrite) BOOL uiLockState;

@property (nonatomic, readwrite) int currentHeartbeatTimerInterval;

@property (nonatomic, readwrite) int lockStateToken;
@property (nonatomic, strong) BKSProcessAssertion *backgroundingAssertion;

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
        
        // States
        self.uiLockState = NO;
        self.updateQueuedForUnlock = NO;
        self.signingTimer = nil;
        self.currentHeartbeatTimerInterval = [RPVResources heartbeatTimerInterval];
        
        // Notifications
        [self _registerForDarwinNotifications];
        
        // Handle initial locked state
        [self _handleInitialLockedState];
    }
    
    return self;
}

- (void)attemptBackgroundSigningIfNecessary:(void (^)(void))completionHandler {
    if (![RPVResources shouldAutomaticallyResign]) {
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

- (void)startBackgroundMonitoringIfNecessary {
    // If background signing enabled, run!
    if ([RPVResources shouldAutomaticallyResign]) {
        [self _startBackgroundMonitoring];
    }
}

//////////////////////////////////////////////////////////////////////////////////
// Internal methods.
//////////////////////////////////////////////////////////////////////////////////

- (void)_registerForDarwinNotifications {
    // Setup notifications for un/locking of the device.
    __weak RPVBackgroundSigningManager *weakSelf = self;
    int status = notify_register_dispatch("com.apple.springboard.lockstate", &_lockStateToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l), ^(int info) {
        
        uint64_t state = UINT64_MAX;
        notify_get_state(_lockStateToken, &state);
        
        if (state != 0) {
            [weakSelf _springboardDidEmitLockedState];
        } else {
            [weakSelf _springboardDidEmitUnlockedState];
        }
    });
    if (status != NOTIFY_STATUS_OK) {
        NSLog(@"Registration for lock notifications failed (%u)\n", status);
        return;
    }
    
    // Notifications sent from preference updates.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userDidUpdateAutomaticSigningPreference:) name:@"com.matchstic.reprovision.ios/automaticResignDidChange" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userDidUpdateHeartbeatIntervalPreference:) name:@"com.matchstic.reprovision.ios/heartbeatIntervalDidChange" object:nil];
    
    // Notifications for debugging.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userDidTapDebugStartBackgroundSigning:) name:@"com.matchstic.reprovision.ios/debugStartBackgroundSign" object:nil];
}

- (void)_handleInitialLockedState {
    uint64_t state = UINT64_MAX;
    notify_get_state(_lockStateToken, &state);
    
    if (state != 0) {
        [self _springboardDidEmitLockedState];
    } else {
        [self _springboardDidEmitUnlockedState];
    }
}

- (void)_userDidTapDebugStartBackgroundSigning:(id)sender {
    // Start a new signing routine.
    [self _startBackgroundSigningInNewTask];
}

- (void)_userDidUpdateAutomaticSigningPreference:(id)sender {
    NSLog(@"*** [ReProvision] :: User did change automatic signing status.");
    // Stop/start timers
    // aquire/release BKProcessAssertion
    
    if ([RPVResources shouldAutomaticallyResign]) {
        [self _startBackgroundMonitoring];
    } else {
        [self _stopBackgroundMonitoring];
    }
}

- (void)_userDidUpdateHeartbeatIntervalPreference:(id)sender {
    NSLog(@"*** [ReProvision] :: User did change heartbeat interval.");
    // If autosigning is enabled, restart timer.
    if ([RPVResources shouldAutomaticallyResign]) {
        [self _restartHeartbeatTimer];
    }
}

- (void)_restartHeartbeatTimer {
    NSLog(@"*** [ReProvision] :: Restarting signing timer.");
    self.signingTimer = [NSTimer scheduledTimerWithTimeInterval:[RPVResources heartbeatTimerInterval] target:self selector:@selector(_heartbeatTimerDidFire:) userInfo:nil repeats:YES];
}

- (void)_stopHeartbeatTimer {
    [self.signingTimer invalidate];
    self.signingTimer = nil;
}

- (void)_heartbeatTimerDidFire:(id)sender {
    if (self.uiLockState == YES) {
        NSLog(@"*** [ReProvision] :: Signing timer fired: update queued");
        self.updateQueuedForUnlock = YES;
        [self _showNotificationForQueuedUpdate];
    } else {
        // Do checks for Low Power Mode stuff.
        BOOL isInLPM = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
        if (isInLPM && ![RPVResources shouldResignInLowPowerMode]) {
            NSLog(@"*** [ReProvision] :: Signing skipped: in Low Power Mode, and user set to not sign.");
            return;
        }
        
        [self _startBackgroundSigningInNewTask];
    }
}

- (void)_springboardDidEmitLockedState {
    NSLog(@"*** [ReProvision] :: Device was locked.");
    self.uiLockState = YES;
}

- (void)_springboardDidEmitUnlockedState {
    NSLog(@"*** [ReProvision] :: Device was unlocked.");
    self.uiLockState = NO;
    
    if (self.updateQueuedForUnlock) {
        self.updateQueuedForUnlock = NO;
        
        [self _startBackgroundSigningInNewTask];
    }
}

- (void)_showNotificationForQueuedUpdate {
    if ([self anyApplicationsNeedingResigning]) {
        [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"Re-signing Queued" body:@"Unlock your device to resign applications." isDebugMessage:NO isUrgentMessage:YES andNotificationID:/*@"resignQueued"*/nil];
    } else {
        [[RPVNotificationManager sharedInstance] sendNotificationWithTitle:@"" body:@"No applications need re-signing at this time." isDebugMessage:NO isUrgentMessage:NO andNotificationID:/*@"resignQueued"*/nil];
    }
}

- (void)_aquireProcessAssertion {
    NSLog(@"*** [ReProvision] :: Aquiring background assertion");
    
    pid_t currentPid = [[NSProcessInfo processInfo] processIdentifier];
    
#if TARGET_OS_SIMULATOR
    return;
#else
    self.backgroundingAssertion = [[BKSProcessAssertion alloc] initWithPID:currentPid flags:(BKSProcessAssertionFlagPreventSuspend | BKSProcessAssertionFlagAllowIdleSleep) reason:BKSProcessAssertionReasonFinishTask name:[[NSBundle mainBundle] bundleIdentifier] withHandler:^(BOOL success) {
        if (success) {
            // Need to do anything here?
            NSLog(@"*** [ReProvision] :: Did aquire background assertion");
        } else {
            NSLog(@"*** [ReProvision] :: Failed to aquire background assertion");
        }
    }];
#endif
}

- (void)_releaseProcessAssertion {
    NSLog(@"*** [ReProvision] :: Releasing background assertion");
    [self.backgroundingAssertion invalidate];
    self.backgroundingAssertion = nil;
}

- (void)_startBackgroundMonitoring {
    NSLog(@"*** [ReProvision] :: Starting background monitoring");
    
    // Start background timer.
    [self _restartHeartbeatTimer];
    
    // Process assertion to prevent suspension.
    [self _aquireProcessAssertion];
}

- (void)_stopBackgroundMonitoring {
    NSLog(@"*** [ReProvision] :: Stopping background monitoring");
    
    // Stop signing timer
    [self _stopHeartbeatTimer];
    
    // Last thing
    [self _releaseProcessAssertion];
}

- (void)_startBackgroundSigningInNewTask {
    UIApplication *application = [UIApplication sharedApplication];
    UIBackgroundTaskIdentifier __block bgTask = [application beginBackgroundTaskWithName:@"ReProvision Background Signing" expirationHandler:^{
        // We should never be called due to using the unboundedTaskCompletion background mode.
        // Putting code here for completeness.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    [self attemptBackgroundSigningIfNecessary:^{
        // Done, so stop this background task.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
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
