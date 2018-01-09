//
//  EEResources.m
//  Extender Installer
//
//  Created by Matt Clarke on 20/04/2017.
//
//

#import "EEResources.h"
#import "SAMKeychain.h"
#import "EEPackageDatabase.h"
#import "EEAppleServices.h"
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

@interface Extender : UIApplication
- (void)sendLocalNotification:(NSString*)title andBody:(NSString*)body;
- (void)_reloadHeartbeatTimer;
@end

#define SERVICE @"com.cydia.Extender"

// Codesigning stuff.

#define CS_OPS_ENTITLEMENTS_BLOB 7
#define MAX_CSOPS_BUFFER_LEN 3*PATH_MAX // 3K < 1 page

int csops(pid_t pid, unsigned int ops, void * useraddr, size_t usersize);

struct csheader {
    uint32_t magic;
    uint32_t length;
};

static NSDictionary *_getEntitlementsPlist() {
    pid_t process_id = getpid();
    CFMutableDataRef data = NULL;
    struct csheader header;
    uint32_t bufferlen;
    int ret;
    
    ret = csops(process_id, CS_OPS_ENTITLEMENTS_BLOB, &header, sizeof(header));
    
    if (ret != -1 || errno != ERANGE) {
        NSLog(@"csops failed: %s\n", strerror(errno));
        return [NSDictionary dictionary];
    } else {
        bufferlen = ntohl(header.length);
        
        data = CFDataCreateMutable(NULL, bufferlen);
        CFDataSetLength(data, bufferlen);
        
        ret = csops(process_id, CS_OPS_ENTITLEMENTS_BLOB, CFDataGetMutableBytePtr(data), bufferlen);
        
        CFDataDeleteBytes(data, CFRangeMake(0, 8));
        
        // Data now contains our entitlements.
        
        NSError *error;
        NSPropertyListFormat format;
        
        id plist = [NSPropertyListSerialization propertyListWithData:(__bridge NSData*)data options:NSPropertyListImmutable format:&format error:&error];
        
        if (error) {
            NSLog(@"ERROR: %@", error);
        }
        
        if (data)
            CFRelease(data);
        
        return plist;
    }
}

@implementation EEResources

+ (BOOL)shouldShowDebugAlerts {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"showDebugAlerts"];
    return value ? [value boolValue] : NO;
}

+ (BOOL)shouldShowAlerts {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"showAlerts"];
    return value ? [value boolValue] : YES;
}

+ (BOOL)shouldShowNonUrgentAlerts {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"showNonUrgentAlerts"];
    return value ? [value boolValue] : NO;
}

// How many days left until expiry.
+ (int)thresholdForResigning {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"thresholdForResigning"];
    return value ? [value intValue] : 2;
}

+ (BOOL)shouldAutomaticallyResign {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"resign"];
    return value ? [value boolValue] : YES;
}

+ (BOOL)shouldResignInLowPowerMode {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"resignInLowPowerMode"];
    return value ? [value boolValue] : NO;
}

+ (NSTimeInterval)heartbeatTimerInterval {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"heartbeatTimerInterval"];
    int time = value ? [value intValue] : 2;
    
    NSTimeInterval interval = 3600;
    interval *= time;
    
    return interval;
}

+ (void)reloadHeartbeatTimer {
    [(Extender*)[UIApplication sharedApplication] _reloadHeartbeatTimer];
}

+ (BOOL)shouldAutoRevokeIfNeeded {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"shouldAutoRevokeIfNeeded"];
    return value ? [value boolValue] : NO;
}

+ (NSString*)username {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"cachedUsername2"];
}

+ (NSString*)password {
    return [SAMKeychain passwordForService:SERVICE account:[self username]];
}

+ (void)storeUsername:(NSString*)username andPassword:(NSString*)password {
    [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"cachedUsername2"];
    
    // Add password to Keychain.
    [SAMKeychain setPassword:password forService:SERVICE account:username];
}

+ (NSString*)getTeamID {
    //NSDictionary *entitlements = _getEntitlementsPlist();
    //NSString *teamID = [entitlements objectForKey:@"com.apple.developer.team-identifier"];
    
    //return teamID;
    
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"teamID"];
}

+ (void)storeTeamID:(NSString*)teamID {
    [[NSUserDefaults standardUserDefaults] setObject:teamID forKey:@"teamID"];
}

+ (void)signOut {
    NSString *username = [self username];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"cachedUsername2"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"teamID"];
    
    // Remove password from Keychain
    [SAMKeychain deletePasswordForService:SERVICE account:username];
}

+ (void)signInWithCallback:(void (^)(BOOL, NSString*))completionHandler {
    Extender *application = (Extender*)[UIApplication sharedApplication];
    
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Apple Developer" message:@"Your password is only sent to Apple." preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *attempt = [UIAlertAction actionWithTitle:@"Sign In" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        // Check the validity of this login. Don't dismiss until it is valid.
        NSArray *textFields = [controller textFields];
        UITextField *userField = [textFields objectAtIndex:0];
        UITextField *passField = [textFields objectAtIndex:1];
        
        __block NSString * username = userField.text;
        
        if ([userField.text isEqualToString:@""] || !userField.text || [passField.text isEqualToString:@""] || !passField.text) {
            [application.keyWindow.rootViewController presentViewController:controller animated:YES completion:nil];
            return;
        }
        
        // Once validated, we store the username and password to NSUserDefaults and the keychain respectively.
        
        [EEAppleServices signInWithUsername:userField.text password:passField.text andCompletionHandler:^(NSError *error, NSDictionary *plist) {
           
            NSString *userString = [plist objectForKey:@"userString"];
            if ((!userString || [userString isEqualToString:@""]) && plist) {
                // Success!
                
                [EEResources storeUsername:userField.text andPassword:passField.text];
                
                // Clear from notification center if needed.
                UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                [center removeDeliveredNotificationsWithIdentifiers:@[@"login"]];
                [center removePendingNotificationRequestsWithIdentifiers:@[@"login"]];
                
                // We also want to pull the Team ID for this user, rather than find it on installation.
                [EEAppleServices listTeamsWithCompletionHandler:^(NSError *error, NSDictionary *plist) {
                    if (error) {
                        // oh shit.
                        [application sendLocalNotification:@"Error" andBody:error.localizedDescription];
                        completionHandler(NO, nil);
                        return;
                    }
                    
                    NSArray *teams = [plist objectForKey:@"teams"];
                    NSString *teamId;
                    
                    // We don't want to be working off a group cert if we can help it.
                    for (NSDictionary *team in teams) {
                        NSString *type = [team objectForKey:@"type"];
                        
                        if ([type isEqualToString:@"Individual"]) {
                            teamId = [team objectForKey:@"teamId"];
                            break;
                        }
                    }
                    
                    [EEResources storeTeamID:teamId];
                    
                    // All done!
                    [application sendLocalNotification:@"Sign In" andBody:@"Successfully signed in."];
                    [application sendLocalNotification:@"Debug" andBody:[NSString stringWithFormat:@"Got Team ID: %@", teamId]];
                    completionHandler(YES, username);
                }];
                
                return;
            } else if (plist) {
                // Failure. Update UI.
                controller.message = userString;
                
                // -22938 => App Specific Pwd?
                // -20101 => incorrect credentials.
                
                NSString *resultCode = [plist objectForKey:@"resultCode"];
                
                if ([resultCode isEqualToString:@"-22938"]) {
                    controller.title = @"App Specific Password";
                }
            } else {
                controller.message = [NSString stringWithFormat:@"Error: %@", error.description];
            }
            
            // Reshow controller!
            [application.keyWindow.rootViewController presentViewController:controller animated:YES completion:nil];
            
        }];
    }];
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [controller dismissViewControllerAnimated:YES completion:nil];
        completionHandler(NO, nil);
    }];
    
    [controller addAction:cancel];
    [controller addAction:attempt];
    
    [controller addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Apple ID";
        textField.secureTextEntry = NO;
        textField.autocapitalizationType = 0;
        textField.autocorrectionType = 1;
        textField.keyboardType = 1;
        textField.returnKeyType = 4;
    }];
    
    [controller addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Password";
        textField.secureTextEntry = YES;
        textField.autocapitalizationType = 0;
        textField.autocorrectionType = 1;
        textField.keyboardType = 1;
        textField.returnKeyType = 9;
    }];
    
    [application.keyWindow.rootViewController presentViewController:controller animated:YES completion:nil];
}

+ (NSDictionary *)provisioningProfileAtPath:(NSString *)path {
    NSError *err;
    NSString *stringContent = [NSString stringWithContentsOfFile:path encoding:NSASCIIStringEncoding error:&err];
    stringContent = [stringContent componentsSeparatedByString:@"<plist version=\"1.0\">"][1];
    stringContent = [NSString stringWithFormat:@"%@%@", @"<plist version=\"1.0\">", stringContent];
    stringContent = [stringContent componentsSeparatedByString:@"</plist>"][0];
    stringContent = [NSString stringWithFormat:@"%@%@", stringContent, @"</plist>"];
    
    NSData *stringData = [stringContent dataUsingEncoding:NSASCIIStringEncoding];
    
    NSError *error;
    NSPropertyListFormat format;
    
    id plist = [NSPropertyListSerialization propertyListWithData:stringData options:NSPropertyListImmutable format:&format error:&error];
    
    return plist;
}

+ (void)removeExistingProvisioningProfileForApplication:(NSString*)bundleIdentifier withCallback:(void (^)(BOOL))completionHandler {
    
    [EEAppleServices signInWithUsername:[EEResources username] password:[EEResources password] andCompletionHandler:^(NSError *error, NSDictionary *plist) {
        if (error) {
            // Oh shit.
            completionHandler(NO);
            return;
        }
        
        // We also want to pull the Team ID for this user, rather than find it on installation.
        [EEAppleServices listTeamsWithCompletionHandler:^(NSError *error, NSDictionary *plist) {
            if (error) {
                completionHandler(NO);
                return;
            }
            
            NSArray *teams = [plist objectForKey:@"teams"];
            NSString *teamId;
            
            // We don't want to be working off a group cert if we can help it.
            for (NSDictionary *team in teams) {
                NSString *type = [team objectForKey:@"type"];
                
                if ([type isEqualToString:@"Individual"]) {
                    teamId = [team objectForKey:@"teamId"];
                    break;
                }
            }
            
            [EEAppleServices deleteProvisioningProfileForApplication:bundleIdentifier andTeamID:teamId withCompletionHandler:^(NSError *error, NSDictionary *plist) {
                if (error) {
                    completionHandler(NO);
                    return;
                }

                // Done!
                completionHandler(YES);
            }];
        }];
    }];
}

+ (void)attemptToRevokeCertificateWithCallback:(void (^)(BOOL))completionHandler {
    if (![EEResources username]) {
        // User needs to sign in.
        [EEResources signInWithCallback:^(BOOL success, NSString *username) {
            if (success) {
                [EEResources attemptToRevokeCertificateWithCallback:completionHandler];
            }
        }];
    }
    
    Extender *application = (Extender*)[UIApplication sharedApplication];
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Revoke Certificates" message:@"Revoking any developer certificates will require all applications using them to be re-signed.\n\nAre you sure you wish to continue?" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *attempt = [UIAlertAction actionWithTitle:@"Revoke" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        // Alright, user is sure...
        [self _actuallyRevokeCertificatesWithAlert:controller andCallback:completionHandler];
    }];
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [controller dismissViewControllerAnimated:YES completion:nil];
        completionHandler(NO);
    }];
    
    [controller addAction:cancel];
    [controller addAction:attempt];
    
    [application.keyWindow.rootViewController presentViewController:controller animated:YES completion:nil];
}

+ (void)_actuallyRevokeCertificatesWithAlert:(UIAlertController*)controller andCallback:(void (^)(BOOL))completionHandler {
    Extender *application = (Extender*)[UIApplication sharedApplication];
    
    // First, we need the myAcInfo value to be set in AppleServices.
    [EEAppleServices signInWithUsername:[EEResources username] password:[EEResources password] andCompletionHandler:^(NSError *error, NSDictionary *plist) {
        if (error) {
            // Oh shit.
            [application sendLocalNotification:@"Error" andBody:error.localizedDescription];
            completionHandler(NO);
            return;
        }
        
        // Now, list all teams so we can find the certs for the teams the user is in.
        [EEAppleServices listTeamsWithCompletionHandler:^(NSError *error, NSDictionary *plist) {
            if (error) {
                // oh shit.
                [application sendLocalNotification:@"Error" andBody:error.localizedDescription];
                completionHandler(NO);
                return;
            }
            
            NSArray *teams = [plist objectForKey:@"teams"];
            NSString *teamId;
            
            // We don't want to be revoking a group cert if we can help it.
            for (NSDictionary *team in teams) {
                NSString *type = [team objectForKey:@"type"];
                
                if ([type isEqualToString:@"Individual"]) {
                    teamId = [team objectForKey:@"teamId"];
                    break;
                }
            }
            
            // We now have the team ID.
            [EEAppleServices listAllDevelopmentCertificatesForTeamID:teamId withCompletionHandler:^(NSError *error, NSDictionary *plist) {
                if (error) {
                    // oh shit.
                    [application sendLocalNotification:@"Error" andBody:error.localizedDescription];
                    completionHandler(NO);
                }
                
                NSArray *certs = [plist objectForKey:@"certificates"];
                NSMutableArray *serials = [NSMutableArray array];
                for (NSDictionary *cert in certs) {
                    // To revoke a certificate, we need its serial number.

                    // Note though that we won't revoke the certifcates that do not include a machine name.
                    //if ([cert objectForKey:@"machineName"]) {
                        NSString *serial = [cert objectForKey:@"serialNumber"];
                        [serials addObject:serial];
                    //}
                }
                
                [self _revokeSerials:serials withTeamID:teamId count:0 andCompletionHandler:^(int revoked, NSError *error) {
                    if (error) {
                        // oh shit.
                        [application sendLocalNotification:@"Error" andBody:error.localizedDescription];
                        completionHandler(NO);
                        return;
                    }
                    
                    // Done revoking!
                    completionHandler(YES);
                    
                    if (controller) {
                        UIAlertController *endcontroller = [UIAlertController alertControllerWithTitle:@"Revoke Certificates" message:[NSString stringWithFormat:@"%d certificate%@ revoked.\n\nYou will need to manually re-sign applications by pressing 'Re-sign' in the Installed tab.", revoked, revoked == 1 ? @" was" : @"s were"] preferredStyle:UIAlertControllerStyleAlert];
                    
                        UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
                            [controller dismissViewControllerAnimated:YES completion:nil];
                        }];
                    
                        [endcontroller addAction:cancel];
                    
                        [application.keyWindow.rootViewController presentViewController:endcontroller animated:YES completion:nil];
                    }
                }];
            }];
        }];
    }];
}

+ (void)_revokeSerials:(NSArray*)serials withTeamID:(NSString*)teamId count:(int)certs andCompletionHandler:(void(^)(int, NSError*))completionHandler {
    
    // guard.
    if (serials.count == 0) {
        completionHandler(certs, nil);
        return;
    }
    
    NSString *serial = [serials firstObject];
    [EEAppleServices revokeCertificateForSerialNumber:serial andTeamID:teamId withCompletionHandler:^(NSError *error, NSDictionary *plist) {
        if (error) {
            completionHandler(certs, error);
            return;
        }
        
        // Pop current serial off array and recurse.
        NSMutableArray *array = [serials mutableCopy];
        [array removeObject:serial];
            
        [self _revokeSerials:array withTeamID:teamId count:certs+1 andCompletionHandler:completionHandler];
    }];
}

/////////////////////////////////////////////////////////////////////
#pragma mark Fix some damn annoying issues.

+ (void)cleanupExpiredProvisioningCertificatesWithCompletionHandler:(void(^)(BOOL))completionHandler {
    // Due to annoyances, this has been removed.
    completionHandler(YES);
    return;
    
    /*
     * Within /var/MobileDevice/ProvisioningProfiles are copies of embedded.mobileprovision for 
     * applications.
     *
     * Testing has shown that Extender may crash when attempting to generate manifest.plist for 
     * a given app if multiple (expired) certificates already are present here. My assumption is
     * that it is assumed iOS will auto-clear these certificates. Though, as to why it crashes
     * is anyone's guess.
     *
     * See: https://github.com/Matchstic/Extender-Installer/issues/ for a crash log.
     *
     * This problem becomes apparent if the user revoke certificates on device.
     */
    
    // Each filename in this directory is the UUID of a provisioning profile.
    [EEAppleServices signInWithUsername:[EEResources username] password:[EEResources password] andCompletionHandler:^(NSError *error, NSDictionary *plist) {
        if (error) {
            NSLog(@"Error: %@", error);
            completionHandler(NO);
            return;
        }
        
        // Why tho.
        @try {
        // We also want to pull the Team ID for this user, rather than find it on installation.
        [EEAppleServices listTeamsWithCompletionHandler:^(NSError *error, NSDictionary *plist) {
            if (error) {
                NSLog(@"Error: %@", error);
                completionHandler(NO);
                return;
            }
            
            NSString *teamId;
            
            // Why tho.
            @try {
                NSArray *teams = [plist objectForKey:@"teams"];
                
                // We don't want to be working off a group cert if we can help it.
                for (NSDictionary *team in teams) {
                    NSString *type = [team objectForKey:@"type"];
                    
                    if ([type isEqualToString:@"Individual"]) {
                        teamId = [team objectForKey:@"teamId"];
                        break;
                    }
                }
            } @catch (NSException *e) {
                // wtf.
                NSLog(@"Error: %@", e);
                return;
            }
            
            [EEAppleServices listAllProvisioningProfilesForTeamID:teamId withCompletionHandler:^(NSError *error, NSDictionary *plist) {
                if (error) {
                    NSLog(@"Error: %@", error);
                    completionHandler(NO);
                    return;
                }
                
                // Why tho.
                @try {
                
                // Generate an array of currently valid provisioning certificates.
                
                NSMutableArray *uuids = [NSMutableArray array];
                
                NSArray *provisioningProfiles = [plist objectForKey:@"provisioningProfiles"];
                for (NSDictionary *profile in provisioningProfiles) {
                    NSString *UUID = [profile objectForKey:@"UUID"];
                    
                    if (UUID) {
                        [uuids addObject:UUID];
                    }
                }
                
                // Now, run through the directory and delete whatever filename isn't in that array
                NSString *basePath = @"/var/MobileDevice/ProvisioningProfiles/";
                for (NSString *filename in [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:nil] copy]) {
                    
                    if (![uuids containsObject:filename]) {
                        NSError *error;
                        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", basePath, filename] error:&error];
                    }
                }
                
                completionHandler(YES);
                    
                } @catch (NSException *e) {
                    // wtf.
                    NSLog(@"Error: %@", e);
                    return;
                }
            }];
        }];
        } @catch (NSException *e) {
            // I am beyond the point of caring with this issue, and quite frankly I don't want to update this
            // project again. You can judge me on the excessive try/catch all you want, I know it's not a sensible
            // resolution and shouldn't be in production code.
            
            NSLog(@"Error: %@", e);
            return;
        }
    }];
}

+ (void)reloadSettings {
    
}

@end
