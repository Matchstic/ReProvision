//
//  RPVDaemonListener.m
//  iOS Daemon
//
//  Created by Matt Clarke on 05/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVDaemonListener.h"
#import <notify.h>

#if TARGET_OS_TV
#define APPLICATION_IDENTIFIER "com.matchstic.reprovision.tvos"
#else
#define APPLICATION_IDENTIFIER "com.matchstic.reprovision.ios"
#endif

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
@property (nonatomic, readwrite) BOOL showQueuedAlertWhenDisplayOn;
@property (nonatomic, readwrite) BOOL uiLockState;
@property (nonatomic, readwrite) BOOL displayState;
@property (nonatomic, readwrite) BOOL springboardDidLaunchSeen;

@property (nonatomic, strong) NSTimer *signingTimer;

@property (nonatomic, strong) BKSProcessAssertion *applicationBackgroundAssertion;

@end

@implementation RPVDaemonListener
    
- (void)reloadSettings {
    // Reload settings.
    NSLog(@"*** [reprovisiond] :: Reloading settings");
    
    CFPreferencesAppSynchronize(CFSTR(APPLICATION_IDENTIFIER));
    
    CFArrayRef keyList = CFPreferencesCopyKeyList(CFSTR(APPLICATION_IDENTIFIER), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    
    if (!keyList) {
        self.settings = [NSMutableDictionary dictionary];
    } else {
        CFDictionaryRef dictionary = CFPreferencesCopyMultiple(keyList, CFSTR(APPLICATION_IDENTIFIER), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        
        self.settings = [(__bridge NSDictionary *)dictionary copy];
        
        CFRelease(dictionary);
        CFRelease(keyList);
    }
}

- (void)setPreferenceKey:(NSString*)key withValue:(id)value {
    if (!key || !value) {
        NSLog(@"*** [reprovisiond] :: Not setting value, as one of the arguments is null");
        return;
    }
    
    NSMutableDictionary *mutableSettings = [self.settings mutableCopy];
    
    [mutableSettings setObject:value forKey:key];
    
    // Write to CFPreferences
    CFPreferencesSetValue ((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, CFSTR(APPLICATION_IDENTIFIER), kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    
    self.settings = mutableSettings;
    
    // Sync
    CFPreferencesAppSynchronize(CFSTR(APPLICATION_IDENTIFIER));
}

- (id)getPreferenceKey:(NSString*)key {
    return [self.settings objectForKey:key];
}
    
- (void)initialiseListener {
    // Start timer for signing etc
    [self reloadSettings];
    
    // Setup states - assuming that we're starting with Cydia etc open
    // If from reboot, SpringBoard states will override this
    self.uiLockState = NO;
    self.updateQueuedForUnlock = NO;
    self.displayState = YES;

    // Load from disk the next fire date, and adjust signing timer for that
    [self _startSigningTimer];
}

- (void)_startSigningTimer {
    NSDate *nextFireDate = [self getPreferenceKey:@"nextFireDate"];
    NSTimeInterval nextFireInterval = [self heartbeatTimerInterval];
    
    NSLog(@"*** [reprovisiond] :: DEBUG :: Got stored fire date: %@", nextFireDate);
    
    if (nextFireDate != nil) {
        nextFireInterval = [nextFireDate timeIntervalSinceDate:[NSDate date]];
        
        if (nextFireInterval < 0) {
            NSLog(@"*** [reprovisiond] :: DEBUG :: Fire date has been and gone whilst reprovisiond was not running!");
            nextFireInterval = 5; // seconds
        }
    }
    
    NSLog(@"*** [reprovisiond] :: Starting signing timer, next fire in: %f minutes", (float)nextFireInterval / 60.0);
    
    self.signingTimer = [NSTimer timerWithTimeInterval:nextFireInterval target:self selector:@selector(signingTimerDidFire:) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.signingTimer forMode:NSDefaultRunLoopMode];
}
    
- (void)_restartSigningTimerWithInterval:(NSTimeInterval)interval {
    NSLog(@"*** [reprovisiond] :: Restarting signing timer, next fire in: %f minutes", (float)interval / 60.0);
    
    if (self.signingTimer)
        [self.signingTimer invalidate];
    
    self.signingTimer = [NSTimer timerWithTimeInterval:interval target:self selector:@selector(signingTimerDidFire:) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.signingTimer forMode:NSDefaultRunLoopMode];
    
    // Persist next fire date in the event of crash or shutdown
    [self setPreferenceKey:@"nextFireDate" withValue:[[NSDate date] dateByAddingTimeInterval:interval]];
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
    [self _restartSigningTimerWithInterval:[self heartbeatTimerInterval]];
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
    NSLog(@"*** [reprovisiond] :: Requesting application to check login credentials.");
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
    
    // Wait for an acknowledgement receipt
    NSTimer *acknowledgementTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                                     target:self
                                                                   selector:@selector(_didFireAcknowledgementTimeout:)
                                                                   userInfo:@{@"notification": [NSNumber numberWithInt:notification]}
                                                                    repeats:NO];
    
    int status, token;
    status = notify_register_dispatch("com.matchstic.reprovision.ios/didReceiveNotification", &token, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l), ^(int info) {
        
        // Just cancel the timeout timer.
        [acknowledgementTimer invalidate];
    });
}

- (void)_didFireAcknowledgementTimeout:(NSTimer*)timer {
    NSLog(@"*** [reprovisiond] :: ERROR :: Timeout on command: %@", [timer userInfo][@"notification"]);
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
    
    // Setup state for new SpringBoard launch
    self.springboardDidLaunchSeen = YES;
    self.uiLockState = YES;
    // self.updateQueuedForUnlock = NO; -> Not resetting since there may actually be a queued signing!
    self.displayState = NO;
}

- (void)sb_didUILockNotification {
    // Just update state.
    NSLog(@"*** [reprovisiond] :: Device was locked.");
    self.uiLockState = YES;
}

- (void)sb_didUIUnlockNotification {
    // Start a signing routine since we had one trigger whilst locked.
    NSLog(@"*** [reprovisiond] :: Device was unlocked.");
    
    self.uiLockState = NO;
    
    // Handle queued signing
    if (self.updateQueuedForUnlock) {
        self.updateQueuedForUnlock = NO;
        [self _initiateNewSigningRoutine];
        
        // Restart timer now with full duration!
        [self _restartSigningTimerWithInterval:[self heartbeatTimerInterval]];
    }
}

- (void)bb_backlightChanged:(int)state {
    self.displayState = state > 0;
    
    if (state > 0) {
        NSLog(@"*** [reprovisiond] :: Display turned on");
        
        if (self.uiLockState == YES) {
            // Handle launching the app for credentials checks after SpringBoard launches
            if (self.springboardDidLaunchSeen) {
                self.springboardDidLaunchSeen = NO;
                
                NSLog(@"*** [reprovisiond] :: Checking credentials after reaching a sane point since SpringBoard launched.");
                [self _initiateApplicationCheckForCredentials];
                
                // Re-display queued alert if needed
                if (self.updateQueuedForUnlock)
                    [self _showApplicationNotificationForQueuedUpdate];
            }
        }
        
        // Restarting timer as needed.
        {
            NSDate *nextFireDate = [self getPreferenceKey:@"nextFireDate"];
            NSTimeInterval nextFireInterval = [nextFireDate timeIntervalSinceDate:[NSDate date]];
            
            if (nextFireInterval <= 5) { // seconds
                NSLog(@"*** [reprovisiond] :: DEBUG :: Timer would have (or is about to) expire, so requesting signing checks");
                [self signingTimerDidFire:nil];
            } else {
                // Restart the timer for this remaining interval
                NSLog(@"*** [reprovisiond] :: DEBUG :: Restarting signing timer due to wake, with interval: %f minutes", (float)nextFireInterval / 60.0);
                [self _restartSigningTimerWithInterval:nextFireInterval];
            }
        }
    } else {
        NSLog(@"*** [reprovisiond] :: Display turned off");
        
        // Stopping timer. If it fires when off, well, likely nothing happens due to be being in deep sleep
        NSLog(@"*** [reprovisiond] :: DEBUG :: Stopping signing timer due to sleep");
        [self.signingTimer invalidate];
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
        NSLog(@"*** [reprovisiond] :: Preferences update received.");
            
        // Update our internal preferences from NSUserDefaults' shared suite.
        NSTimeInterval oldInterval = [self heartbeatTimerInterval];
        [self reloadSettings];
        NSTimeInterval newInterval = [self heartbeatTimerInterval];
            
        // Restart if prefs changed!
        if (oldInterval != newInterval)
            [self _restartSigningTimerWithInterval:newInterval];
            
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
