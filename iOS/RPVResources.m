//
//  RPVResources.m
//  
//
//  Created by Matt Clarke on 09/01/2018.
//

#import "RPVResources.h"
#import "SAMKeychain.h"

#define SERVICENAME @"com.matchstic.ReProvision"

@implementation RPVResources

/////////////////////////////////////////////////////////////////////////////////////////////////
// User Settings
/////////////////////////////////////////////////////////////////////////////////////////////////

+ (BOOL)shouldShowDebugAlerts {
    id value = [self preferenceValueForKey:@"showDebugAlerts"];
    return value ? [value boolValue] : NO;
}

+ (BOOL)shouldShowAlerts {
    id value = [self preferenceValueForKey:@"showAlerts"];
    return value ? [value boolValue] : YES;
}

+ (BOOL)shouldShowNonUrgentAlerts {
    id value = [self preferenceValueForKey:@"showNonUrgentAlerts"];
    return value ? [value boolValue] : NO;
}

// How many days left until expiry.
+ (int)thresholdForResigning {
    id value = [self preferenceValueForKey:@"thresholdForResigning"];
    return value ? [value intValue] : 2;
}

+ (BOOL)shouldAutomaticallyResign {
    id value = [self preferenceValueForKey:@"resign"];
    return value ? [value boolValue] : YES;
}

+ (BOOL)shouldResignInLowPowerMode {
    id value = [self preferenceValueForKey:@"resignInLowPowerMode"];
    return value ? [value boolValue] : NO;
}

+ (BOOL)shouldAutoRevokeIfNeeded {
    id value = [self preferenceValueForKey:@"shouldAutoRevokeIfNeeded"];
    return value ? [value boolValue] : NO;
}

+ (id)preferenceValueForKey:(NSString*)key {
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

+ (void)setPreferenceValue:(id)value forKey:(NSString*)key withNotification:(NSString*)notification {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    
    // Broadcast notification as Darwin
    [self _broadcastNotification:notification withUserInfo:nil];
}

+ (void)_broadcastNotification:(NSString*)notifiation withUserInfo:(NSDictionary*)userInfo {
    [[NSNotificationCenter defaultCenter] postNotificationName:notifiation object:nil userInfo:userInfo];
}

/////////////////////////////////////////////////////////////////////////////////////////////////
// User Account
/////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString*)getUsername {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"cachedUsername"];
}

+ (NSString*)getPassword {
    return [SAMKeychain passwordForService:SERVICENAME account:[self getUsername]];
}

+ (NSString*)getTeamID {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"cachedTeamID"];
}

+ (void)storeUsername:(NSString*)username password:(NSString*)password andTeamID:(NSString*)teamId {
    [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"cachedUsername"];
    
    [SAMKeychain setPassword:password forService:SERVICENAME account:username];
    
    [[NSUserDefaults standardUserDefaults] setObject:teamId forKey:@"cachedTeamID"];
}

+ (void)userDidRequestAccountSignIn {
    [self _broadcastNotification:@"RPVDisplayAccountSignInController" withUserInfo:nil];
}

+ (void)userDidRequestAccountSignOut {
    NSString *username = [self getUsername];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"cachedUsername"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"cachedTeamID"];
    
    // Remove password from Keychain
    [SAMKeychain deletePasswordForService:SERVICENAME account:username];
    
    [self _broadcastNotification:@"RPVDisplayAccountSignInController" withUserInfo:nil];
}

@end
