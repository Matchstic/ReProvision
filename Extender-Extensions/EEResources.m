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
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

@interface Extender : UIApplication
- (void)sendLocalNotification:(NSString*)title andBody:(NSString*)body;
@end

#define SERVICE @"com.cydia.Extender"

@implementation EEResources

+ (BOOL)shouldShowDebugAlerts {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"showDebugAlerts"];
    return value ? [value boolValue] : NO;
}

+ (BOOL)shouldShowAlerts {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"showAlerts"];
    return value ? [value boolValue] : YES;
}

// How many days left until expiry.
+ (int)thresholdForResigning {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"thresholdForResigning"];
    return value ? [value intValue] : 2;
}

+ (NSString*)username {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"cachedUsername"];
}

+ (NSString*)password {
    return [SAMKeychain passwordForService:SERVICE account:[self username]];
}

+ (void)storeUsername:(NSString*)username andPassword:(NSString*)password {
    [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"cachedUsername"];
    
    // Add password to Keychain.
    [SAMKeychain setPassword:password forService:SERVICE account:username];
}

+ (void)signOut {
    NSString *username = [self username];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"cachedUsername"];
    
    // Remove password from Keychain
    [SAMKeychain deletePasswordForService:SERVICE account:username];
}

+ (void)signInWithCallback:(void (^)(BOOL))completionHandler {
    Extender *application = (Extender*)[UIApplication sharedApplication];
    
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Apple Developer" message:@"Your password is only sent to Apple." preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *attempt = [UIAlertAction actionWithTitle:@"Sign In" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        // Check the validity of this login. Don't dismiss until it is valid.
        NSArray *textFields = [controller textFields];
        UITextField *userField = [textFields objectAtIndex:0];
        UITextField *passField = [textFields objectAtIndex:1];
        
        if ([userField.text isEqualToString:@""] || !userField.text || [passField.text isEqualToString:@""] || !passField.text) {
            [application.keyWindow.rootViewController presentViewController:controller animated:YES completion:nil];
            return;
        }
        
        // Once validated, we store the username and password to NSUserDefaults and the keychain respectively.
        
        NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://idmsa.apple.com/IDMSWebAuth/clientDAW.cgi"]];
        
        [request setHTTPMethod:@"POST"];
        [request setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
        [request setValue:@"en-us" forHTTPHeaderField:@"Accept-Language"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
        
        NSString *postString = [NSString stringWithFormat:@"appIdKey=ba2ec180e6ca6e6c6a542255453b24d6e6e5b2be0cc48bc1b0d8ad64cfe0228f&userLocale=en_US&protocolVersion=A1234&appleId=%@&password=%@&format=plist", userField.text, passField.text];
        
        [request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
        
        // The result of this request will determine what we do next.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error;
            NSURLResponse* response;
            NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            
            NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *userString = [plist objectForKey:@"userString"];
                if ((!userString || [userString isEqualToString:@""]) && data) {
                    // Success!
                    
                    [EEResources storeUsername:userField.text andPassword:passField.text];
                    
                    [application sendLocalNotification:@"Sign In" andBody:@"Successfully signed in."];
                    
                    // Clear from notification center if needed.
                    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                    [center removeDeliveredNotificationsWithIdentifiers:@[@"login"]];
                    [center removePendingNotificationRequestsWithIdentifiers:@[@"login"]];
                    
                    completionHandler(YES);
                    return;
                } else if (data) {
                    // Failure. Update UI.
                    controller.message = userString;
                } else {
                    controller.message = [NSString stringWithFormat:@"Error: %@", error.description];
                }
                
                // Reshow controller!
                [application.keyWindow.rootViewController presentViewController:controller animated:YES completion:nil];
            });
        });
    }];
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [controller dismissViewControllerAnimated:YES completion:nil];
        completionHandler(NO);
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
    
    NSString *error;
    NSPropertyListFormat format;
    
    id plist = [NSPropertyListSerialization propertyListFromData:stringData  mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error];
    
    return plist;
}

+ (BOOL)attemptToRevokeCertificate {
    NSError *error;
    
    return error == nil;
}

+ (void)reloadSettings {
    
}

@end
