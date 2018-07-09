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
    
#if __cplusplus
}
#endif

///////////////////////////////////////////////////////////////////////////
// Main daemon class
///////////////////////////////////////////////////////////////////////////

@interface RPVDaemonListener ()

@property (nonatomic, readwrite) int lockstateToken;
@property (nonatomic, readwrite) int springboardBootToken;

@property (nonatomic, readwrite) BOOL springboardDidLaunchSeen;

@end

@implementation RPVDaemonListener

- (void)_relaunchApplicationIfNecessary:(BOOL)force {
#if TARGET_OS_SIMULATOR
    return;
#else
    
    pid_t servicePid;
    SBSProcessIDForDisplayIdentifier(CFSTR(APPLICATION_IDENTIFIER), &servicePid);
    
    if (servicePid > 0 && !force) {
        // Running, no need to relaunch
    } else {
        int result = SBSLaunchApplicationWithIdentifierAndLaunchOptions(CFSTR(APPLICATION_IDENTIFIER), nil, 1);
        if (result) {
            NSLog(@"*** [reprovisiond] :: Failed to launch application for reason: %@", SBSApplicationLaunchingErrorString(result));
        }
    }
#endif
}

- (void)sb_didFinishLaunchingNotification {
    // Give the user a notification if they need to sign in to ReProvision after a respring/restart
    NSLog(@"*** [reprovisiond] :: SpringBoard did start launching.");
    
    self.springboardDidLaunchSeen = YES;
}

- (void)sb_didUILockNotification {
    if (self.springboardDidLaunchSeen) {
        self.springboardDidLaunchSeen = NO;
        
        NSLog(@"*** [reprovisiond] :: Launching application in background...");
        [self _relaunchApplicationIfNecessary:YES];
    }
}
    
//////////////////////////////////////////////////////////////////////////
// Runloop
//////////////////////////////////////////////////////////////////////////
    
- (void)timerFireMethod:(NSTimer *)timer {
    int status;
    static char first = 0;
    
    if (!first) {
        // Setup notifications for un/locking of the device.
        __weak RPVDaemonListener *weakSelf = self;
        status = notify_register_dispatch("com.apple.springboard.lockstate", &_lockstateToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l), ^(int info) {
            
            uint64_t state = UINT64_MAX;
            notify_get_state(_lockstateToken, &state);
            
            if (state != 0) {
                [weakSelf sb_didUILockNotification];
            }
        });
        
        // SpringBoard boot-up
        status = notify_register_dispatch("SBSpringBoardDidLaunchNotification", &_springboardBootToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l), ^(int token) {
            
            // No state associated with this message.
            [weakSelf sb_didFinishLaunchingNotification];
        });
        
        first = 1;
        
        return; // We don't want to update the things on the first run, only when requested.
    }
    
    // Check for needing to relaunch the application
    [self _relaunchApplicationIfNecessary:NO];
}

@end
