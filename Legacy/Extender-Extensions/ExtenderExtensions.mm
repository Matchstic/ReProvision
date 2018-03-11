#line 1 "/Users/matt/iOS/Projects/Extender-Installer/Legacy/Extender-Extensions/ExtenderExtensions.xm"








#import <UIKit/UIKit.h>
#import "EEPackagesViewController.h"
#import "EESettingsController.h"
#import "EEPackage.h"
#import "EEPackageDatabase.h"
#import "EEResources.h"
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>

#import "SAMKeychain.h"




@interface InstalledController : UIViewController
@end

@interface Extender : UIApplication
-(void)sendLocalNotification:(NSString*)title andBody:(NSString*)body;
-(void)sendLocalNotification:(NSString*)title body:(NSString*)body withID:(NSString*)identifier;
- (void)beginResignRoutine:(int)location;
- (void)resignApplication:(EEPackage*)package;
- (void)registerForRemoteNotificationTypes:(unsigned long long)arg1;
- (void)_resignTimerCallback:(id)sender;
- (void)_requestAppleDeveloperLogin;
- (void)_reloadHeartbeatTimer;

- (_Bool)application:(id)arg1 openURL:(id)arg2 sourceApplication:(id)arg3 annotation:(id)arg4;
@end

@interface SBApplication : NSObject
- (id)bundleIdentifier;
@end

@interface UIAlertController (Private)
- (void)_dismissWithAction:(UIAlertAction*)arg1;
@end

@interface UIAlertAction (Private)
- (id )handler;
@end




static EEPackagesViewController *packagesController;
static EESettingsController *settingsController;
static NSTimer *heartbeatTimer;
dispatch_queue_t resignQueue;





#include <substrate.h>
#if defined(__clang__)
#if __has_feature(objc_arc)
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif

@class NSFileManager; @class UIAlertController; @class NEVPNConnection; @class NEVPNManager; @class Extender; @class NSURLSession; @class NETunnelProviderManager; @class UNUserNotificationCenter; @class CyextTabBarController; @class SBApplication; 


#line 62 "/Users/matt/iOS/Projects/Extender-Installer/Legacy/Extender-Extensions/ExtenderExtensions.xm"
static NSArray* (*_logos_orig$Extender$Extender$defaultStartPages)(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL); static NSArray* _logos_method$Extender$Extender$defaultStartPages(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL); static UIViewController * (*_logos_orig$Extender$Extender$pageForURL$forExternal$withReferrer$)(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, NSURL *, BOOL, NSString *); static UIViewController * _logos_method$Extender$Extender$pageForURL$forExternal$withReferrer$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, NSURL *, BOOL, NSString *); static void _logos_method$Extender$Extender$sendLocalNotification$body$withID$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, NSString*, NSString*, NSString*); static void _logos_method$Extender$Extender$sendLocalNotification$andBody$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, NSString*, NSString*); static void _logos_method$Extender$Extender$userNotificationCenter$didReceiveNotificationResponse$withCompletionHandler$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, UNUserNotificationCenter *, UNNotificationResponse *, void (^)(void)); static void _logos_method$Extender$Extender$userNotificationCenter$willPresentNotification$withCompletionHandler$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, UNUserNotificationCenter *, UNNotification *, void (^)(UNNotificationPresentationOptions options)); static void _logos_method$Extender$Extender$_requestAppleDeveloperLogin(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$Extender$Extender$application$didFinishLaunchingWithOptions$)(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, UIApplication *, id); static void _logos_method$Extender$Extender$application$didFinishLaunchingWithOptions$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, UIApplication *, id); static void _logos_method$Extender$Extender$applicationDidEnterBackground$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, UIApplication *); static void _logos_method$Extender$Extender$application$performFetchWithCompletionHandler$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, UIApplication *, void (^)(UIBackgroundFetchResult)); static void _logos_method$Extender$Extender$_reloadHeartbeatTimer(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL); static void _logos_method$Extender$Extender$_resignTimerCallback$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, id); static void _logos_method$Extender$Extender$beginResignRoutine$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, int); static _Bool (*_logos_orig$Extender$Extender$application$openURL$sourceApplication$annotation$)(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, UIApplication*, NSURL*, UIApplication*, id); static _Bool _logos_method$Extender$Extender$application$openURL$sourceApplication$annotation$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, UIApplication*, NSURL*, UIApplication*, id); static BOOL (*_logos_orig$Extender$Extender$openURL$)(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, NSURL*); static BOOL _logos_method$Extender$Extender$openURL$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST, SEL, NSURL*); static void (*_logos_orig$Extender$CyextTabBarController$setViewControllers$)(_LOGOS_SELF_TYPE_NORMAL CyextTabBarController* _LOGOS_SELF_CONST, SEL, NSArray*); static void _logos_method$Extender$CyextTabBarController$setViewControllers$(_LOGOS_SELF_TYPE_NORMAL CyextTabBarController* _LOGOS_SELF_CONST, SEL, NSArray*); static void (*_logos_orig$Extender$UIAlertController$_logBeingPresented)(_LOGOS_SELF_TYPE_NORMAL UIAlertController* _LOGOS_SELF_CONST, SEL); static void _logos_method$Extender$UIAlertController$_logBeingPresented(_LOGOS_SELF_TYPE_NORMAL UIAlertController* _LOGOS_SELF_CONST, SEL); static NSURL * (*_logos_orig$Extender$NSFileManager$containerURLForSecurityApplicationGroupIdentifier$)(_LOGOS_SELF_TYPE_NORMAL NSFileManager* _LOGOS_SELF_CONST, SEL, NSString *); static NSURL * _logos_method$Extender$NSFileManager$containerURLForSecurityApplicationGroupIdentifier$(_LOGOS_SELF_TYPE_NORMAL NSFileManager* _LOGOS_SELF_CONST, SEL, NSString *); static BOOL (*_logos_orig$Extender$NEVPNConnection$startVPNTunnelAndReturnError$)(_LOGOS_SELF_TYPE_NORMAL NEVPNConnection* _LOGOS_SELF_CONST, SEL, NSError **); static BOOL _logos_method$Extender$NEVPNConnection$startVPNTunnelAndReturnError$(_LOGOS_SELF_TYPE_NORMAL NEVPNConnection* _LOGOS_SELF_CONST, SEL, NSError **); static int (*_logos_orig$Extender$NEVPNConnection$status)(_LOGOS_SELF_TYPE_NORMAL NEVPNConnection* _LOGOS_SELF_CONST, SEL); static int _logos_method$Extender$NEVPNConnection$status(_LOGOS_SELF_TYPE_NORMAL NEVPNConnection* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$Extender$NEVPNManager$saveToPreferencesWithCompletionHandler$)(_LOGOS_SELF_TYPE_NORMAL NEVPNManager* _LOGOS_SELF_CONST, SEL, void (^)(NSError *error)); static void _logos_method$Extender$NEVPNManager$saveToPreferencesWithCompletionHandler$(_LOGOS_SELF_TYPE_NORMAL NEVPNManager* _LOGOS_SELF_CONST, SEL, void (^)(NSError *error)); static void (*_logos_meta_orig$Extender$NETunnelProviderManager$loadAllFromPreferencesWithCompletionHandler$)(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST, SEL, void (^)(NSArray *managers, NSError *error)); static void _logos_meta_method$Extender$NETunnelProviderManager$loadAllFromPreferencesWithCompletionHandler$(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST, SEL, void (^)(NSArray *managers, NSError *error)); static NSURLSessionDataTask * (*_logos_orig$Extender$NSURLSession$dataTaskWithURL$completionHandler$)(_LOGOS_SELF_TYPE_NORMAL NSURLSession* _LOGOS_SELF_CONST, SEL, NSURL *, void (^)(NSData *data, NSURLResponse *response, NSError *error)); static NSURLSessionDataTask * _logos_method$Extender$NSURLSession$dataTaskWithURL$completionHandler$(_LOGOS_SELF_TYPE_NORMAL NSURLSession* _LOGOS_SELF_CONST, SEL, NSURL *, void (^)(NSData *data, NSURLResponse *response, NSError *error)); static UNUserNotificationCenter* (*_logos_orig$Extender$UNUserNotificationCenter$initWithBundleIdentifier$)(_LOGOS_SELF_TYPE_INIT UNUserNotificationCenter*, SEL, NSString*) _LOGOS_RETURN_RETAINED; static UNUserNotificationCenter* _logos_method$Extender$UNUserNotificationCenter$initWithBundleIdentifier$(_LOGOS_SELF_TYPE_INIT UNUserNotificationCenter*, SEL, NSString*) _LOGOS_RETURN_RETAINED; 









#pragma mark Insert new pages



static NSArray* _logos_method$Extender$Extender$defaultStartPages(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    NSArray *original = _logos_orig$Extender$Extender$defaultStartPages(self, _cmd);
    
    NSMutableArray *additions = [original mutableCopy];
    [additions addObject:@[@"cyext://settings"]];
    
    return additions;
}

static UIViewController * _logos_method$Extender$Extender$pageForURL$forExternal$withReferrer$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSURL * url, BOOL external, NSString * referrer) {
    if (url) {
        NSString *scheme = [[url scheme] lowercaseString];
        
        if (scheme && [scheme isEqualToString:@"cyext"]) {
            if ([[url absoluteString] isEqualToString:@"cyext://installed"]) {
                
                if (!packagesController) {
                    packagesController = [[EEPackagesViewController alloc] init];
                }
                
                return packagesController;
            } else if ([[url absoluteString] isEqualToString:@"cyext://settings"]) {
                
                if (!settingsController) {
                    settingsController = [[EESettingsController alloc] init];
                }
                
                return settingsController;
            }
        }	
    }
    
    return _logos_orig$Extender$Extender$pageForURL$forExternal$withReferrer$(self, _cmd, url, external, referrer);
}





static void _logos_method$Extender$CyextTabBarController$setViewControllers$(_LOGOS_SELF_TYPE_NORMAL CyextTabBarController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSArray* arg1) {
    
    NSMutableArray *controllers([arg1 mutableCopy]);
    
    UITabBarItem *item2 = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemMore tag:0];
    UINavigationController *controller2 = [[UINavigationController alloc] init];
    [controller2 setTabBarItem:item2];
    [controllers addObject:controller2];
    
    _logos_orig$Extender$CyextTabBarController$setViewControllers$(self, _cmd, controllers);
}



#pragma mark Notifications handling




static void _logos_method$Extender$Extender$sendLocalNotification$body$withID$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSString* title, NSString* body, NSString* identifier) {
    
    
    
    if ([title isEqualToString:@"Debug"] && ![EEResources shouldShowDebugAlerts]) {
        return;
    }
    
    UNMutableNotificationContent *objNotificationContent = [[UNMutableNotificationContent alloc] init];
    
    objNotificationContent.title = title;
    objNotificationContent.body = body;
    objNotificationContent.sound = nil;
    
    
    objNotificationContent.badge = @([[UIApplication sharedApplication] applicationIconBadgeNumber]);
    
    
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger                                             triggerWithTimeInterval:1 repeats:NO];
    
    UNNotificationRequest *request = [UNNotificationRequest
                                      requestWithIdentifier:identifier                                                                   content:objNotificationContent trigger:trigger];
    
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        
    }];
}


static void _logos_method$Extender$Extender$sendLocalNotification$andBody$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSString* title, NSString* body) {
    [self sendLocalNotification:title body:body withID:[NSString stringWithFormat:@"notif_%f", [[NSDate date] timeIntervalSince1970]]];
}

#pragma mark Request user Apple ID from opening relevant notification.


static void _logos_method$Extender$Extender$userNotificationCenter$didReceiveNotificationResponse$withCompletionHandler$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, UNUserNotificationCenter * center, UNNotificationResponse * response, void (^completionHandler)(void)) {
    
    NSString *identifier = response.notification.request.identifier;
    
    if ([identifier isEqualToString:@"login"]) {
        
        [self _requestAppleDeveloperLogin];
    }
    
    completionHandler();
}


static void _logos_method$Extender$Extender$userNotificationCenter$willPresentNotification$withCompletionHandler$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, UNUserNotificationCenter * center, UNNotification * notification, void (^completionHandler)(UNNotificationPresentationOptions options)) {
    
    completionHandler(UNNotificationPresentationOptionAlert);
}


static void _logos_method$Extender$Extender$_requestAppleDeveloperLogin(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    [EEResources signInWithCallback:^(BOOL result, NSString *username) {}];
}

#pragma mark Callbacks for background execution

static void _logos_method$Extender$Extender$application$didFinishLaunchingWithOptions$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, UIApplication * application, id options) {
    _logos_orig$Extender$Extender$application$didFinishLaunchingWithOptions$(self, _cmd, application, options);
    
    resignQueue = dispatch_queue_create("com.cydia.Extender.queue", NULL);
    
    [self _reloadHeartbeatTimer];
    
    
    [self beginResignRoutine:0];
    
    
    if ([self respondsToSelector:@selector(registerUserNotificationSettings:)]) {        
        [self registerUserNotificationSettings:[objc_getClass("UIUserNotificationSettings") settingsForTypes:7 categories:nil]];
        [self registerForRemoteNotifications];
    } else {
        [self registerForRemoteNotificationTypes:7];
    }
    
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = (id<UNUserNotificationCenterDelegate>)self;

    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert) completionHandler:^(BOOL granted, NSError * _Nullable error) {
         if (error) {
             
         }
    }];
    
    
    
    [SAMKeychain setAccessibilityType:kSecAttrAccessibleAfterFirstUnlock];
}


static void _logos_method$Extender$Extender$applicationDidEnterBackground$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, UIApplication * application) {
    
    
    
    
    
}


static void _logos_method$Extender$Extender$application$performFetchWithCompletionHandler$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, UIApplication * application, void (^completionHandler)(UIBackgroundFetchResult)) {
    
    [self beginResignRoutine:2];
    
    completionHandler(UIBackgroundFetchResultNoData);
}


static void _logos_method$Extender$Extender$_reloadHeartbeatTimer(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    NSTimeInterval interval = [EEResources heartbeatTimerInterval];
    
    if (heartbeatTimer) {
        [heartbeatTimer invalidate];
        heartbeatTimer = nil;
    }
    
    heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(_resignTimerCallback:) userInfo:nil repeats:YES];
    
    
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:interval];
}


static void _logos_method$Extender$Extender$_resignTimerCallback$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id sender) {
    [self beginResignRoutine:3];
}


static void _logos_method$Extender$Extender$beginResignRoutine$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, int location) {
    
    if (![EEResources shouldAutomaticallyResign]) {
        return;
    }
    
    UIApplication *application = [UIApplication sharedApplication];
    UIBackgroundTaskIdentifier __block bgTask = [application beginBackgroundTaskWithName:@"Cydia Extender Auto Sign" expirationHandler:^{
        
        
        
        
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    
    dispatch_async(resignQueue, ^{
        
        
        [[EEPackageDatabase sharedInstance] rebuildDatabase];
        [[EEPackageDatabase sharedInstance] resignApplicationsIfNecessaryWithTaskID:bgTask andCheckExpiry:YES];
    });
}



#pragma mark Auto-fill user Apple ID details.






static void _logos_method$Extender$UIAlertController$_logBeingPresented(_LOGOS_SELF_TYPE_NORMAL UIAlertController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    
    BOOL hasCachedUser = [EEResources username] != nil;
    
    if (hasCachedUser && [self.title isEqualToString:@"Apple Developer"]) {
        
        NSArray *textFields = [self textFields];
        
        if (textFields.count == 2) {
            
            
            
            
            NSString *username = [EEResources username];
            NSString *password = [EEResources password];
            
            
            UITextField *userField = [textFields objectAtIndex:0];
            userField.text = username;
            
            UITextField *passField = [textFields objectAtIndex:1];
            passField.text = password;
            
            
            
            
            UIAlertAction *attemptAction;
            for (UIAlertAction *action in self.actions) {
                if ([action.title isEqualToString:@"Attempt"]) {
                    attemptAction = action;
                    break;
                }
            }
            
            
            [self _dismissWithAction:attemptAction];
        }
        
    } else if ([self.title isEqualToString:[[NSBundle mainBundle] localizedStringForKey:@"ERROR" value:@"ERROR" table:nil]]) {
        [[EEPackageDatabase sharedInstance] errorDidOccur:self.message];
        
        
        UIAlertAction *closeAction = [self.actions firstObject];
        
        
        [self _dismissWithAction:closeAction];
    } else {
        _logos_orig$Extender$UIAlertController$_logBeingPresented(self, _cmd);
    }
}



#pragma mark Override default IPA from URL behaviour



static _Bool _logos_method$Extender$Extender$application$openURL$sourceApplication$annotation$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, UIApplication* arg1, NSURL* url, UIApplication* arg3, id arg4) {
    if (arg3 != self) {
        
        
        
        [self sendLocalNotification:@"Installing" andBody:@"Application is being installed."];
        
        return _logos_orig$Extender$Extender$application$openURL$sourceApplication$annotation$(self, _cmd, arg1, url, arg3, arg4);
    } else {
        
        return _logos_orig$Extender$Extender$application$openURL$sourceApplication$annotation$(self, _cmd, arg1, url, arg3, arg4);
    }
}



#pragma mark Install signed IPA



static NSURL * _logos_method$Extender$NSFileManager$containerURLForSecurityApplicationGroupIdentifier$(_LOGOS_SELF_TYPE_NORMAL NSFileManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSString * groupIdentifier) {
    return [NSURL fileURLWithPath:EXTENDER_DOCUMENTS];
}





static BOOL _logos_method$Extender$Extender$openURL$(_LOGOS_SELF_TYPE_NORMAL Extender* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSURL* url) {
    if ([[url absoluteString] rangeOfString:@"itms-services"].location != NSNotFound) {
        
        
        NSString *path = [EXTENDER_DOCUMENTS stringByAppendingString:@"/Site/signed.ipa"];
        NSURL *pathURL = [NSURL fileURLWithPath:path];
        
        path = [EXTENDER_DOCUMENTS stringByAppendingString:@"/Site/manifest.plist"];
        NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:path];
        
        [[EEPackageDatabase sharedInstance] installPackageAtURL:pathURL withManifest:manifest];
        
        return YES;
    } else {
        return _logos_orig$Extender$Extender$openURL$(self, _cmd, url);
    }
}



#pragma mark Look ma, no VPN!



static BOOL _logos_method$Extender$NEVPNConnection$startVPNTunnelAndReturnError$(_LOGOS_SELF_TYPE_NORMAL NEVPNConnection* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSError ** error) {
    return YES; 
}

static int _logos_method$Extender$NEVPNConnection$status(_LOGOS_SELF_TYPE_NORMAL NEVPNConnection* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    
    return 3;
}





static void _logos_method$Extender$NEVPNManager$saveToPreferencesWithCompletionHandler$(_LOGOS_SELF_TYPE_NORMAL NEVPNManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, void (^completionHandler)(NSError *error)) {
    completionHandler(nil);
    return; 
}





static void _logos_meta_method$Extender$NETunnelProviderManager$loadAllFromPreferencesWithCompletionHandler$(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, void (^completionHandler)(NSArray *managers, NSError *error)) {
    completionHandler([NSArray array], nil); 
}



#pragma mark Don't time out for debug.txt opening.



static NSURLSessionDataTask * _logos_method$Extender$NSURLSession$dataTaskWithURL$completionHandler$(_LOGOS_SELF_TYPE_NORMAL NSURLSession* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSURL * url, void (^completionHandler)(NSData *data, NSURLResponse *response, NSError *error)) {
    
    if ([[url path] rangeOfString:@"debug.txt"].location != NSNotFound) {
        completionHandler([NSData dataWithBytes:"hello" length:6], nil, nil);
        return nil;
    } else {
        return _logos_orig$Extender$NSURLSession$dataTaskWithURL$completionHandler$(self, _cmd, url, completionHandler);
    }
}



#pragma mark Fixes for UNUserNotificationCenter and stashing



static UNUserNotificationCenter* _logos_method$Extender$UNUserNotificationCenter$initWithBundleIdentifier$(_LOGOS_SELF_TYPE_INIT UNUserNotificationCenter* __unused self, SEL __unused _cmd, NSString* bundleID) _LOGOS_RETURN_RETAINED {
    id result;
    
    if (!bundleID) {
        bundleID = @"com.cydia.Extender";
    }
    
    @try {
        result = _logos_orig$Extender$UNUserNotificationCenter$initWithBundleIdentifier$(self, _cmd, bundleID);
    } @catch (NSException *e) {
        result = _logos_orig$Extender$UNUserNotificationCenter$initWithBundleIdentifier$(self, _cmd, @"com.cydia.Extender");
    }
    
    return result;
}



#pragma mark Hook Team ID into csops().













__unused static size_t (*_logos_orig$Extender$strlen)(const char *str); __unused static size_t _logos_function$Extender$strlen(const char *str) {
    size_t len = _logos_orig$Extender$strlen(str);
    
    if (strncmp(str, "AAAAAAAAAA", 10) == 0 && len == 10) {
        NSString *teamID = [EEResources getTeamID];
        if (teamID)
            memcpy((void*)str, (const void *)[teamID UTF8String], 10);
    }
    
    return _logos_orig$Extender$strlen(str);
}






static _Bool (*_logos_orig$SpringBoard$SBApplication$shouldAutoLaunchOnBootOrInstall)(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); static _Bool _logos_method$SpringBoard$SBApplication$shouldAutoLaunchOnBootOrInstall(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); static _Bool (*_logos_orig$SpringBoard$SBApplication$_shouldAutoLaunchOnBootOrInstall$)(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL, _Bool); static _Bool _logos_method$SpringBoard$SBApplication$_shouldAutoLaunchOnBootOrInstall$(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL, _Bool); static _Bool (*_logos_orig$SpringBoard$SBApplication$_shouldAutoLaunchForVoIP)(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); static _Bool _logos_method$SpringBoard$SBApplication$_shouldAutoLaunchForVoIP(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); static _Bool (*_logos_orig$SpringBoard$SBApplication$shouldAutoRelaunchAfterExit)(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); static _Bool _logos_method$SpringBoard$SBApplication$shouldAutoRelaunchAfterExit(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); static _Bool (*_logos_orig$SpringBoard$SBApplication$supportsFetchBackgroundMode)(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); static _Bool _logos_method$SpringBoard$SBApplication$supportsFetchBackgroundMode(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); static _Bool (*_logos_orig$SpringBoard$SBApplication$supportsBackgroundAppRefresh)(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); static _Bool _logos_method$SpringBoard$SBApplication$supportsBackgroundAppRefresh(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); static _Bool (*_logos_orig$SpringBoard$SBApplication$supportsRemoteNotificationBackgroundMode)(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); static _Bool _logos_method$SpringBoard$SBApplication$supportsRemoteNotificationBackgroundMode(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST, SEL); 

#pragma mark Force auto-relaunch, and backgrounding



static _Bool _logos_method$SpringBoard$SBApplication$shouldAutoLaunchOnBootOrInstall(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return _logos_orig$SpringBoard$SBApplication$shouldAutoLaunchOnBootOrInstall(self, _cmd);
}

static _Bool _logos_method$SpringBoard$SBApplication$_shouldAutoLaunchOnBootOrInstall$(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, _Bool arg1) {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return _logos_orig$SpringBoard$SBApplication$_shouldAutoLaunchOnBootOrInstall$(self, _cmd, arg1);
}

static _Bool _logos_method$SpringBoard$SBApplication$_shouldAutoLaunchForVoIP(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return _logos_orig$SpringBoard$SBApplication$_shouldAutoLaunchForVoIP(self, _cmd);
}

static _Bool _logos_method$SpringBoard$SBApplication$shouldAutoRelaunchAfterExit(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return _logos_orig$SpringBoard$SBApplication$shouldAutoRelaunchAfterExit(self, _cmd);
}

static _Bool _logos_method$SpringBoard$SBApplication$supportsFetchBackgroundMode(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return _logos_orig$SpringBoard$SBApplication$supportsFetchBackgroundMode(self, _cmd);
}

static _Bool _logos_method$SpringBoard$SBApplication$supportsBackgroundAppRefresh(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return _logos_orig$SpringBoard$SBApplication$supportsBackgroundAppRefresh(self, _cmd);
}

static _Bool _logos_method$SpringBoard$SBApplication$supportsRemoteNotificationBackgroundMode(_LOGOS_SELF_TYPE_NORMAL SBApplication* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    if ([[self bundleIdentifier] isEqualToString:@"com.cydia.Extender"]) {
        return YES;
    }
    
    return _logos_orig$SpringBoard$SBApplication$supportsRemoteNotificationBackgroundMode(self, _cmd);
}






static __attribute__((constructor)) void _logosLocalCtor_e2bac904(int __unused argc, char __unused **argv, char __unused **envp) {
    {}

    
    BOOL sb = [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
    
    if (sb) {
        {Class _logos_class$SpringBoard$SBApplication = objc_getClass("SBApplication"); MSHookMessageEx(_logos_class$SpringBoard$SBApplication, @selector(shouldAutoLaunchOnBootOrInstall), (IMP)&_logos_method$SpringBoard$SBApplication$shouldAutoLaunchOnBootOrInstall, (IMP*)&_logos_orig$SpringBoard$SBApplication$shouldAutoLaunchOnBootOrInstall);MSHookMessageEx(_logos_class$SpringBoard$SBApplication, @selector(_shouldAutoLaunchOnBootOrInstall:), (IMP)&_logos_method$SpringBoard$SBApplication$_shouldAutoLaunchOnBootOrInstall$, (IMP*)&_logos_orig$SpringBoard$SBApplication$_shouldAutoLaunchOnBootOrInstall$);MSHookMessageEx(_logos_class$SpringBoard$SBApplication, @selector(_shouldAutoLaunchForVoIP), (IMP)&_logos_method$SpringBoard$SBApplication$_shouldAutoLaunchForVoIP, (IMP*)&_logos_orig$SpringBoard$SBApplication$_shouldAutoLaunchForVoIP);MSHookMessageEx(_logos_class$SpringBoard$SBApplication, @selector(shouldAutoRelaunchAfterExit), (IMP)&_logos_method$SpringBoard$SBApplication$shouldAutoRelaunchAfterExit, (IMP*)&_logos_orig$SpringBoard$SBApplication$shouldAutoRelaunchAfterExit);MSHookMessageEx(_logos_class$SpringBoard$SBApplication, @selector(supportsFetchBackgroundMode), (IMP)&_logos_method$SpringBoard$SBApplication$supportsFetchBackgroundMode, (IMP*)&_logos_orig$SpringBoard$SBApplication$supportsFetchBackgroundMode);MSHookMessageEx(_logos_class$SpringBoard$SBApplication, @selector(supportsBackgroundAppRefresh), (IMP)&_logos_method$SpringBoard$SBApplication$supportsBackgroundAppRefresh, (IMP*)&_logos_orig$SpringBoard$SBApplication$supportsBackgroundAppRefresh);MSHookMessageEx(_logos_class$SpringBoard$SBApplication, @selector(supportsRemoteNotificationBackgroundMode), (IMP)&_logos_method$SpringBoard$SBApplication$supportsRemoteNotificationBackgroundMode, (IMP*)&_logos_orig$SpringBoard$SBApplication$supportsRemoteNotificationBackgroundMode);}
    } else {
        {Class _logos_class$Extender$Extender = objc_getClass("Extender"); MSHookMessageEx(_logos_class$Extender$Extender, @selector(defaultStartPages), (IMP)&_logos_method$Extender$Extender$defaultStartPages, (IMP*)&_logos_orig$Extender$Extender$defaultStartPages);MSHookMessageEx(_logos_class$Extender$Extender, @selector(pageForURL:forExternal:withReferrer:), (IMP)&_logos_method$Extender$Extender$pageForURL$forExternal$withReferrer$, (IMP*)&_logos_orig$Extender$Extender$pageForURL$forExternal$withReferrer$);{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; memcpy(_typeEncoding + i, @encode(NSString*), strlen(@encode(NSString*))); i += strlen(@encode(NSString*)); memcpy(_typeEncoding + i, @encode(NSString*), strlen(@encode(NSString*))); i += strlen(@encode(NSString*)); memcpy(_typeEncoding + i, @encode(NSString*), strlen(@encode(NSString*))); i += strlen(@encode(NSString*)); _typeEncoding[i] = '\0'; class_addMethod(_logos_class$Extender$Extender, @selector(sendLocalNotification:body:withID:), (IMP)&_logos_method$Extender$Extender$sendLocalNotification$body$withID$, _typeEncoding); }{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; memcpy(_typeEncoding + i, @encode(NSString*), strlen(@encode(NSString*))); i += strlen(@encode(NSString*)); memcpy(_typeEncoding + i, @encode(NSString*), strlen(@encode(NSString*))); i += strlen(@encode(NSString*)); _typeEncoding[i] = '\0'; class_addMethod(_logos_class$Extender$Extender, @selector(sendLocalNotification:andBody:), (IMP)&_logos_method$Extender$Extender$sendLocalNotification$andBody$, _typeEncoding); }{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; memcpy(_typeEncoding + i, @encode(UNUserNotificationCenter *), strlen(@encode(UNUserNotificationCenter *))); i += strlen(@encode(UNUserNotificationCenter *)); memcpy(_typeEncoding + i, @encode(UNNotificationResponse *), strlen(@encode(UNNotificationResponse *))); i += strlen(@encode(UNNotificationResponse *)); memcpy(_typeEncoding + i, @encode(void (^)(void)), strlen(@encode(void (^)(void)))); i += strlen(@encode(void (^)(void))); _typeEncoding[i] = '\0'; class_addMethod(_logos_class$Extender$Extender, @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:), (IMP)&_logos_method$Extender$Extender$userNotificationCenter$didReceiveNotificationResponse$withCompletionHandler$, _typeEncoding); }{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; memcpy(_typeEncoding + i, @encode(UNUserNotificationCenter *), strlen(@encode(UNUserNotificationCenter *))); i += strlen(@encode(UNUserNotificationCenter *)); memcpy(_typeEncoding + i, @encode(UNNotification *), strlen(@encode(UNNotification *))); i += strlen(@encode(UNNotification *)); memcpy(_typeEncoding + i, @encode(void (^)(UNNotificationPresentationOptions options)), strlen(@encode(void (^)(UNNotificationPresentationOptions options)))); i += strlen(@encode(void (^)(UNNotificationPresentationOptions options))); _typeEncoding[i] = '\0'; class_addMethod(_logos_class$Extender$Extender, @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:), (IMP)&_logos_method$Extender$Extender$userNotificationCenter$willPresentNotification$withCompletionHandler$, _typeEncoding); }{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; _typeEncoding[i] = '\0'; class_addMethod(_logos_class$Extender$Extender, @selector(_requestAppleDeveloperLogin), (IMP)&_logos_method$Extender$Extender$_requestAppleDeveloperLogin, _typeEncoding); }MSHookMessageEx(_logos_class$Extender$Extender, @selector(application:didFinishLaunchingWithOptions:), (IMP)&_logos_method$Extender$Extender$application$didFinishLaunchingWithOptions$, (IMP*)&_logos_orig$Extender$Extender$application$didFinishLaunchingWithOptions$);{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; memcpy(_typeEncoding + i, @encode(UIApplication *), strlen(@encode(UIApplication *))); i += strlen(@encode(UIApplication *)); _typeEncoding[i] = '\0'; class_addMethod(_logos_class$Extender$Extender, @selector(applicationDidEnterBackground:), (IMP)&_logos_method$Extender$Extender$applicationDidEnterBackground$, _typeEncoding); }{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; memcpy(_typeEncoding + i, @encode(UIApplication *), strlen(@encode(UIApplication *))); i += strlen(@encode(UIApplication *)); memcpy(_typeEncoding + i, @encode(void (^)(UIBackgroundFetchResult)), strlen(@encode(void (^)(UIBackgroundFetchResult)))); i += strlen(@encode(void (^)(UIBackgroundFetchResult))); _typeEncoding[i] = '\0'; class_addMethod(_logos_class$Extender$Extender, @selector(application:performFetchWithCompletionHandler:), (IMP)&_logos_method$Extender$Extender$application$performFetchWithCompletionHandler$, _typeEncoding); }{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; _typeEncoding[i] = '\0'; class_addMethod(_logos_class$Extender$Extender, @selector(_reloadHeartbeatTimer), (IMP)&_logos_method$Extender$Extender$_reloadHeartbeatTimer, _typeEncoding); }{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = '\0'; class_addMethod(_logos_class$Extender$Extender, @selector(_resignTimerCallback:), (IMP)&_logos_method$Extender$Extender$_resignTimerCallback$, _typeEncoding); }{ char _typeEncoding[1024]; unsigned int i = 0; _typeEncoding[i] = 'v'; i += 1; _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; _typeEncoding[i] = 'i'; i += 1; _typeEncoding[i] = '\0'; class_addMethod(_logos_class$Extender$Extender, @selector(beginResignRoutine:), (IMP)&_logos_method$Extender$Extender$beginResignRoutine$, _typeEncoding); }MSHookMessageEx(_logos_class$Extender$Extender, @selector(application:openURL:sourceApplication:annotation:), (IMP)&_logos_method$Extender$Extender$application$openURL$sourceApplication$annotation$, (IMP*)&_logos_orig$Extender$Extender$application$openURL$sourceApplication$annotation$);MSHookMessageEx(_logos_class$Extender$Extender, @selector(openURL:), (IMP)&_logos_method$Extender$Extender$openURL$, (IMP*)&_logos_orig$Extender$Extender$openURL$);Class _logos_class$Extender$CyextTabBarController = objc_getClass("CyextTabBarController"); MSHookMessageEx(_logos_class$Extender$CyextTabBarController, @selector(setViewControllers:), (IMP)&_logos_method$Extender$CyextTabBarController$setViewControllers$, (IMP*)&_logos_orig$Extender$CyextTabBarController$setViewControllers$);Class _logos_class$Extender$UIAlertController = objc_getClass("UIAlertController"); MSHookMessageEx(_logos_class$Extender$UIAlertController, @selector(_logBeingPresented), (IMP)&_logos_method$Extender$UIAlertController$_logBeingPresented, (IMP*)&_logos_orig$Extender$UIAlertController$_logBeingPresented);Class _logos_class$Extender$NSFileManager = objc_getClass("NSFileManager"); MSHookMessageEx(_logos_class$Extender$NSFileManager, @selector(containerURLForSecurityApplicationGroupIdentifier:), (IMP)&_logos_method$Extender$NSFileManager$containerURLForSecurityApplicationGroupIdentifier$, (IMP*)&_logos_orig$Extender$NSFileManager$containerURLForSecurityApplicationGroupIdentifier$);Class _logos_class$Extender$NEVPNConnection = objc_getClass("NEVPNConnection"); MSHookMessageEx(_logos_class$Extender$NEVPNConnection, @selector(startVPNTunnelAndReturnError:), (IMP)&_logos_method$Extender$NEVPNConnection$startVPNTunnelAndReturnError$, (IMP*)&_logos_orig$Extender$NEVPNConnection$startVPNTunnelAndReturnError$);MSHookMessageEx(_logos_class$Extender$NEVPNConnection, @selector(status), (IMP)&_logos_method$Extender$NEVPNConnection$status, (IMP*)&_logos_orig$Extender$NEVPNConnection$status);Class _logos_class$Extender$NEVPNManager = objc_getClass("NEVPNManager"); MSHookMessageEx(_logos_class$Extender$NEVPNManager, @selector(saveToPreferencesWithCompletionHandler:), (IMP)&_logos_method$Extender$NEVPNManager$saveToPreferencesWithCompletionHandler$, (IMP*)&_logos_orig$Extender$NEVPNManager$saveToPreferencesWithCompletionHandler$);Class _logos_class$Extender$NETunnelProviderManager = objc_getClass("NETunnelProviderManager"); Class _logos_metaclass$Extender$NETunnelProviderManager = object_getClass(_logos_class$Extender$NETunnelProviderManager); MSHookMessageEx(_logos_metaclass$Extender$NETunnelProviderManager, @selector(loadAllFromPreferencesWithCompletionHandler:), (IMP)&_logos_meta_method$Extender$NETunnelProviderManager$loadAllFromPreferencesWithCompletionHandler$, (IMP*)&_logos_meta_orig$Extender$NETunnelProviderManager$loadAllFromPreferencesWithCompletionHandler$);Class _logos_class$Extender$NSURLSession = objc_getClass("NSURLSession"); MSHookMessageEx(_logos_class$Extender$NSURLSession, @selector(dataTaskWithURL:completionHandler:), (IMP)&_logos_method$Extender$NSURLSession$dataTaskWithURL$completionHandler$, (IMP*)&_logos_orig$Extender$NSURLSession$dataTaskWithURL$completionHandler$);Class _logos_class$Extender$UNUserNotificationCenter = objc_getClass("UNUserNotificationCenter"); MSHookMessageEx(_logos_class$Extender$UNUserNotificationCenter, @selector(initWithBundleIdentifier:), (IMP)&_logos_method$Extender$UNUserNotificationCenter$initWithBundleIdentifier$, (IMP*)&_logos_orig$Extender$UNUserNotificationCenter$initWithBundleIdentifier$); MSHookFunction((void *)strlen, (void *)&_logos_function$Extender$strlen, (void **)&_logos_orig$Extender$strlen);}
    }
}
