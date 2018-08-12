//
//  RPVDaemonListener.m
//  iOS Daemon
//
//  Created by Matt Clarke on 05/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVDaemonListener.h"
#import <notify.h>

#define APPLICATION_IDENTIFIER "com.matchstic.reprovision.ios"

///////////////////////////////////////////////////////////////////////////
// Private API
///////////////////////////////////////////////////////////////////////////

#if __cplusplus
extern "C" {
#endif
    // SpringBoardServices
    BOOL SBSProcessIDForDisplayIdentifier(CFStringRef identifier, pid_t *pid);
    
    // Needs the com.apple.backboardd.launchapplications entitlement
    int SBSLaunchApplicationWithIdentifierAndLaunchOptions(CFStringRef identifier, CFDictionaryRef launchOptions, BOOL suspended);
    CFStringRef SBSApplicationLaunchingErrorString(int error);
    
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

extern NSString* BKSActivateForEventOptionTypeBackgroundContentFetching;
extern NSString* BKSOpenApplicationOptionKeyActivateForEvent;

@interface BKSProcessAssertion : NSObject
- (id)initWithPID:(pid_t)arg1 flags:(unsigned int)arg2 reason:(BKSProcessAssertionReason)arg3 name:(NSString*)arg4 withHandler:(void (^)(BOOL success))arg5;
- (void)invalidate;
@end

///////////////////////////////////////////////////////////////////////////
// Main daemon class
///////////////////////////////////////////////////////////////////////////

@interface RPVDaemonListener ()

@property (nonatomic, readwrite) int updatePreferencesToken;
@property (nonatomic, readwrite) int debugBackgroundSign;
@property (nonatomic, readwrite) int lockstateToken;
@property (nonatomic, readwrite) int springboardBootToken;
@property (nonatomic, readwrite) int backboardBacklightChangedToken;
@property (nonatomic, readwrite) int applicationNotificationToken;
@property (nonatomic, readwrite) int applicationDidFinishTaskToken;
    
@property (nonatomic, strong) NSDictionary *settings;
@property (nonatomic, strong) NSTimer *assertionFallbackTimer;
@property (nonatomic, readwrite) BOOL updateQueuedForUnlock;
@property (nonatomic, readwrite) BOOL uiLockState;

@property (nonatomic, readwrite) BOOL springboardDidLaunchSeen;

@property (nonatomic, strong) NSTimer *signingTimer;
@property (nonatomic, readwrite) time_t lastLockedTime;
@property (nonatomic, readwrite) NSTimeInterval lastLockedTimeDelta;

@property (nonatomic, strong) BKSProcessAssertion *applicationBackgroundAssertion;

@end

@implementation RPVDaemonListener
    
- (void)reloadSettings {
    // Reload settings.
    NSLog(@"*** [reprovisiond] :: Reloading settings");
    
    CFPreferencesAppSynchronize(CFSTR(APPLICATION_IDENTIFIER));
    self.settings = (__bridge NSDictionary *)CFPreferencesCopyMultiple(CFPreferencesCopyKeyList(CFSTR(APPLICATION_IDENTIFIER), kCFPreferencesCurrentUser, kCFPreferencesAnyHost), CFSTR(APPLICATION_IDENTIFIER), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}
    
- (void)initialiseListener {
    // Start timer for signing, and setup notifications on SB events.
    [self reloadSettings];
    
    // Setup last locked times a
    self.lastLockedTime = time(NULL);
    self.lastLockedTimeDelta = [self heartbeatTimerInterval];

    [self _restartSigningTimer];
}
    
- (void)_restartSigningTimer {
    NSLog(@"*** [reprovisiond] :: Restarting signing timer, interval: every %f hours", (float)[self heartbeatTimerInterval] / 3600.0);
    
    if (self.signingTimer)
        [self.signingTimer invalidate];
    
    self.signingTimer = [NSTimer timerWithTimeInterval:[self heartbeatTimerInterval] target:self selector:@selector(signingTimerDidFire:) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.signingTimer forMode:NSDefaultRunLoopMode];
}
    
- (NSTimeInterval)heartbeatTimerInterval {
    id value = [self.settings objectForKey:@"heartbeatTimerInterval"];
    int time = value ? [value intValue] : 2;
    
    NSTimeInterval interval = 3600;
    interval *= time;
    
    return interval;
}

- (BOOL)canSignInLowPowerMode {
    id value = [self.settings objectForKey:@"resignInLowPowerMode"];
    return value ? [value boolValue] : NO;
}

- (BOOL)shouldAutomaticallyResign {
    id value = [self.settings objectForKey:@"resign"];
    return value ? [value boolValue] : YES;
}
    
- (void)signingTimerDidFire:(id)sender {    
    // Queue the update if needed.
    if (self.uiLockState == YES) {
        NSLog(@"*** [reprovisiond] :: Signing timer fired: update queued");
        self.updateQueuedForUnlock = YES;
        [self _showApplicationNotificationForQueuedUpdate];
    } else {
        // Do checks for Low Power Mode stuff.
        BOOL isInLPM = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
        if (isInLPM && ![self canSignInLowPowerMode]) {
            NSLog(@"*** [reprovisiond] :: Signing skipped: in Low Power Mode, and user set to not sign.");
            return;
        }
        
        if (![self shouldAutomaticallyResign]) {
            NSLog(@"*** [reprovisiond] :: Signing skipped: user disabled automatic re-signing.");
            return;
        }
        
        NSLog(@"*** [reprovisiond] :: Signing timer fired: update now");
        [self _initiateNewSigningRoutine];
    }
    
    // Restart the timer with the full duration.
    [self _restartSigningTimer];
}
    
- (void)_initiateNewSigningRoutine {
    // Launch our companion app backgrounded, and update the notification flag for it to
    // then initiate signing.
    NSLog(@"*** [reprovisiond] :: Starting new background signing routine.");
    [self _launchApplicationBackgroundedWithNotification:1];
}
    
- (void)_initiateApplicationCheckForCredentials {
    // Launch our companion app backgrounded, and update the notification flag for it to
    // then initiate credential checks..
    [self _launchApplicationBackgroundedWithNotification:2];
}

- (void)_showApplicationNotificationForQueuedUpdate {
    NSLog(@"*** [reprovisiond] :: Requesting application to notify users of a queued update.");
    [self _launchApplicationBackgroundedWithNotification:3];
}

- (void)_launchApplicationBackgroundedWithNotification:(int)notification {
    // Send on notification token with state.
    // By setting state first, once SpringBoardServices wakes the app, the corresponding notify_dispatch handler
    // will be run correctly.
    notify_set_state(self.applicationNotificationToken, notification);
    notify_post("com.matchstic.reprovision.ios/applicationNotification");
    
    // Launch the application
    int result = [self _launchApplicationBackgroundedAndAquireAssertion];
    if (result) {
        // Error occured in launch.
        notify_set_state(self.applicationNotificationToken, 0); // Reset state!
#if TARGET_OS_SIMULATOR
#else
        NSLog(@"*** [reprovisiond] :: Error launching application: %@", SBSApplicationLaunchingErrorString(result));
#endif
    }
}

- (int)_launchApplicationBackgroundedAndAquireAssertion {
#if TARGET_OS_SIMULATOR
    return 0;
#else
    
    pid_t servicePid = 0;
    SBSProcessIDForDisplayIdentifier(CFSTR(APPLICATION_IDENTIFIER), &servicePid);
    
    // If running, do assertion now.
    if (servicePid != 0) {
        [self _aquireApplicationBackgroundAssertion];
    }
    
    NSMutableDictionary *launchOptions = [@{} mutableCopy];
    NSDictionary *eventOptions = @{ BKSActivateForEventOptionTypeBackgroundContentFetching : @""};
    
    [launchOptions setObject:eventOptions forKey:BKSOpenApplicationOptionKeyActivateForEvent];
    
    int result = SBSLaunchApplicationWithIdentifierAndLaunchOptions(CFSTR(APPLICATION_IDENTIFIER), (__bridge CFDictionaryRef)(launchOptions), 1);
    
    NSLog(@"*** [reprovisiond] :: Launched application with result: %d", result);
    if (result == 0 && servicePid == 0) {
        // Aquire assertion now that we're launched.
        [self _aquireApplicationBackgroundAssertion];
    }
    
    return result;
#endif
}

- (void)_aquireApplicationBackgroundAssertion {
#if TARGET_OS_SIMULATOR
    return;
#else
    pid_t servicePid;
    SBSProcessIDForDisplayIdentifier(CFSTR(APPLICATION_IDENTIFIER), &servicePid);
    
    if (servicePid != 0) {
        NSLog(@"*** [reprovisiond] :: Aquiring background assertion");
        self.applicationBackgroundAssertion = [[BKSProcessAssertion alloc] initWithPID:servicePid flags:(BKSProcessAssertionFlagPreventSuspend | BKSProcessAssertionFlagAllowIdleSleep) reason:BKSProcessAssertionReasonExternalAccessory name:@APPLICATION_IDENTIFIER withHandler:^(BOOL success) {
            if (success) {
                // Need to do anything here?
                NSLog(@"*** [reprovisiond] :: Did aquire background assertion");
                
                // Start the fallback timer for removing the assertion.
                self.assertionFallbackTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(_assertionFallbackDidFire:) userInfo:nil repeats:NO];
            } else {
                NSLog(@"*** [reprovisiond] :: Failed to aquire background assertion");
            }
        }];
    } else {
        // No PID!
        NSLog(@"*** [reprovisiond] :: Could not find application's PID, might be first launch.");
    }
#endif
}

- (void)_assertionFallbackDidFire:(id)sender {
    NSLog(@"*** [reprovisiond] :: Background assertion fallback did fire.");
    [self _releaseApplicationBackgroundAssertion];
}

- (void)_releaseApplicationBackgroundAssertion {
#if TARGET_OS_SIMULATOR
    return;
#else
    NSLog(@"*** [reprovisiond] :: Releasing background assertion");
    
    if (self.assertionFallbackTimer) {
        [self.assertionFallbackTimer invalidate];
        self.assertionFallbackTimer = nil;
    }
    
    [self.applicationBackgroundAssertion invalidate];
    self.applicationBackgroundAssertion = nil;
#endif
}

- (void)sb_didFinishLaunchingNotification {
    // Give the user a notification if they need to sign in to ReProvision after a respring/restart
    NSLog(@"*** [reprovisiond] :: SpringBoard did start launching.");
    
    self.springboardDidLaunchSeen = YES;
}

- (void)sb_didUILockNotification {
    // Just update state.
    NSLog(@"*** [reprovisiond] :: Device was locked.");
    self.uiLockState = YES;
    
    // If the unlocked timer is running, then we need to stop it.
    // BUT! We need to know how long was left on it to correctly set our timeDelta
    self.lastLockedTime = time(NULL);
    
    if (self.signingTimer != nil) {
        self.lastLockedTimeDelta = fabs([[NSDate date] timeIntervalSinceDate:self.signingTimer.fireDate]);
        [self.signingTimer invalidate];
        
        NSLog(@"*** [reprovisiond] :: Time delta from timer: %f", self.lastLockedTimeDelta);
    } else {
        self.lastLockedTimeDelta = [self heartbeatTimerInterval];
    }
}

- (void)sb_didUIUnlockNotification {
    // Start a signing routine since we had one trigger whilst locked.
    NSLog(@"*** [reprovisiond] :: Device was unlocked.");
    
    // Restart the signing timer with the remaining interval from being locked.
    NSTimeInterval remainingInterval = 0;
    
    // Already fired and waiting for unlock, next one is the full time interval
    if (self.updateQueuedForUnlock)
        remainingInterval = [self heartbeatTimerInterval];
    else
        remainingInterval = fabs(difftime(self.lastLockedTime + self.lastLockedTimeDelta, time(NULL)));
    
    NSLog(@"*** [reprovisiond] :: Restarting timer with interval: %f seconds", remainingInterval);
        
    self.signingTimer = [NSTimer timerWithTimeInterval:remainingInterval target:self selector:@selector(signingTimerDidFire:) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.signingTimer forMode:NSDefaultRunLoopMode];
    
    // Handle queued signing
    if (self.updateQueuedForUnlock) {
        self.updateQueuedForUnlock = NO;
        [self _initiateNewSigningRoutine];
    }
    
    self.uiLockState = NO;
}

- (void)bb_backlightChanged:(int)state {
    if (state > 0) {
        NSLog(@"*** [reprovisiond] :: Display turned on");
        
        if (self.uiLockState == YES) {
            // Handle launching the app for credentials checks after SpringBoard launches
            if (self.springboardDidLaunchSeen) {
                self.springboardDidLaunchSeen = NO;
                
                NSLog(@"*** [reprovisiond] :: Checking credentials after reaching a sane point since SpringBoard launched.");
                [self _initiateApplicationCheckForCredentials];
            }
            
            if (!self.updateQueuedForUnlock) {
                // We're locked, and the display turned on. Check to see if our current time exceeds the stored time + delta.
                if (self.lastLockedTime + self.lastLockedTimeDelta < time(NULL)) {
                    [self signingTimerDidFire:nil];
                } else {
                    NSTimeInterval timeRemaining = self.lastLockedTime + self.lastLockedTimeDelta - time(NULL);
                    
                    int hoursRemaining = timeRemaining / 60 / 60;
                    int minutesRemaining = (timeRemaining - (hoursRemaining*60*60)) / 60;
                    int secondsRemaining = timeRemaining - (hoursRemaining*60*60) - (minutesRemaining*60);
                    
                    NSLog(@"*** [reprovisiond] :: Timer not 'triggered', remaining: %dh %dm %ds", hoursRemaining, minutesRemaining, secondsRemaining);
                }
            }
        }
    } else {
        NSLog(@"*** [reprovisiond] :: Display turned off");
    }
}
    
//////////////////////////////////////////////////////////////////////////
// Runloop
//////////////////////////////////////////////////////////////////////////
    
- (void)timerFireMethod:(NSTimer *)timer {
    int status, check;
    static char first = 0;
    
    if (!first) {
        status = notify_register_check("com.matchstic.reprovision.ios/updatePreferences", &_updatePreferencesToken);
        if (status != NOTIFY_STATUS_OK) {
            fprintf(stderr, "registration failed (%u)\n", status);
            return;
        }
        
        status = notify_register_check("com.matchstic.reprovision.ios/debugStartBackgroundSign", &_debugBackgroundSign);
        if (status != NOTIFY_STATUS_OK) {
            fprintf(stderr, "registration failed (%u)\n", status);
            return;
        }
        
        // Setup notifications for un/locking of the device.
        __weak RPVDaemonListener *weakSelf = self;
        status = notify_register_dispatch("com.apple.springboard.lockstate", &_lockstateToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l), ^(int info) {
            
            uint64_t state = UINT64_MAX;
            notify_get_state(_lockstateToken, &state);
            
            if (state == 0) {
                [weakSelf sb_didUIUnlockNotification];
            } else {
                [weakSelf sb_didUILockNotification];
            }
        });
        
        // SpringBoard boot-up
        status = notify_register_dispatch("SBSpringBoardDidLaunchNotification", &_springboardBootToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l), ^(int token) {
            
            // No state associated with this message.
            [weakSelf sb_didFinishLaunchingNotification];
        });
        
        // backboardd backlight changes
        status = notify_register_dispatch("com.apple.backboardd.backlight.changed", &_backboardBacklightChangedToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0l), ^(int token) {
            
            uint64_t state = UINT64_MAX;
            notify_get_state(_backboardBacklightChangedToken, &state);
            
            [weakSelf bb_backlightChanged:(int)state];
        });
        
        // Application did finish task.
        status = notify_register_dispatch("com.matchstic.reprovision.ios/didFinishBackgroundTask", &_applicationDidFinishTaskToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0l), ^(int token) {
            
            // No state associated with this message.
            [weakSelf _releaseApplicationBackgroundAssertion];
        });
        
        status = notify_register_check("com.matchstic.reprovision.ios/applicationNotification", &_applicationNotificationToken);
        if (status != NOTIFY_STATUS_OK) {
            fprintf(stderr, "registration failed (%u)\n", status);
            return;
        }
        
        first = 1;
        
        // Do first-time setup.
        [self initialiseListener];
        
        return; // We don't want to update the things on the first run, only when requested.
    }
    
    status = notify_check(_updatePreferencesToken, &check);
    if (status == NOTIFY_STATUS_OK && check != 0) {
        NSLog(@"[reprovisiond] :: Preferences update received.");
            
        // Update our internal preferences from NSUserDefaults' shared suite.
        NSTimeInterval oldInterval = [self heartbeatTimerInterval];
        [self reloadSettings];
        NSTimeInterval newInterval = [self heartbeatTimerInterval];
            
        // Restart if prefs changed!
        if (oldInterval != newInterval)
            [self _restartSigningTimer];
            
        // Reset the state so we don't keep reloading settings
        notify_set_state(_updatePreferencesToken, 0);
    }
    
    status = notify_check(_debugBackgroundSign, &check);
    if (status == NOTIFY_STATUS_OK && check != 0) {
        uint64_t incoming = 0;
        notify_get_state(_debugBackgroundSign, &incoming);
        
        if (incoming != 0) {
            NSLog(@"*** [reprovisiond] :: Debugging background signing request recieved.");
            
            // Start a new background routine now.
            [self _initiateNewSigningRoutine];
            
            // Reset the state so we don't keep starting a new routine.
            notify_set_state(_debugBackgroundSign, 0);
        }
    }
}

@end
