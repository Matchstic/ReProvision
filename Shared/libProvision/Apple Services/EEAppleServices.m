//
//  EEAppleServices.m
//  Extender Installer
//
//  Created by Matt Clarke on 28/04/2017.
//
//

#import "EEAppleServices.h"
#import "NSData+GZIP.h"

static NSString *acinfo = @"";
static NSString *_teamid = @"";

@implementation EEAppleServices

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Private methods.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// From: http://stackoverflow.com/a/8088484
+ (NSString*)_urlEncodeString:(NSString*)string {
    if (!string) {
        return @"";
    }
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[string UTF8String];
    int sourceLen = (int)strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

+ (void)_doActionWithName:(NSString*)action systemType:(EESystemType)systemType extraDictionary:(NSDictionary*)extra andCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    // watchOS is treated as iOS
    NSString *os = systemType == EESystemTypeiOS || systemType == EESystemTypewatchOS ? @"ios" : @"tvos";
    NSString *urlStr = [NSString stringWithFormat:@"https://developerservices2.apple.com/services/QH65B2/%@/%@?clientId=XABBG36SBA", os, action];
    
    NSLog(@"Request to URL: %@", urlStr);
    
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlStr]];
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
    [request setValue:@"en-us" forHTTPHeaderField:@"Accept-Language"];
    [request setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Content-Type"]; // Body is a plist.
    [request setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"7.0 (7A120f)" forHTTPHeaderField:@"X-Xcode-Version"];
    
    // The acinfo is set as a cookie for authentication purposes.
    [request setValue:[NSString stringWithFormat:@"myacinfo=%@", acinfo] forHTTPHeaderField:@"Cookie"];
    
    // Now, body.
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setObject:@"XABBG36SBA" forKey:@"clientId"];
    [dict setObject:acinfo forKey:@"myacinfo"];
    [dict setObject:@"QH65B2" forKey:@"protocolVersion"];
    [dict setObject:[[NSUUID UUID] UUIDString] forKey:@"requestId"];
    [dict setObject:@[@"en_US"] forKey:@"userLocale"];
    
    // Automatically switch this dependant on device type.
    /*
     * Available options:
     * mac
     * ios
     * tvos
     * watchos
     */
    switch (systemType) {
        case EESystemTypeiOS:
            [dict setObject:@"ios" forKey:@"DTDK_Platform"];
            //[dict setObject:@"ios" forKey:@"subPlatform"];
            break;
        case EESystemTypewatchOS:
            [dict setObject:@"watchos" forKey:@"DTDK_Platform"];
            //[dict setObject:@"watchOS" forKey:@"subPlatform"];
            break;
        case EESystemTypetvOS:
            [dict setObject:@"tvos" forKey:@"DTDK_Platform"];
            [dict setObject:@"tvOS" forKey:@"subPlatform"];
            break;
        default:
            break;
    }
    
    if (extra) {
        for (NSString *key in extra.allKeys) {
            if ([extra objectForKey:key]) // do a nil check.
                [dict setObject:[extra objectForKey:key] forKey:key];
        }
    }
    
    // We want this as an XML plist.
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    
    // Add content length too.
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)data.length] forHTTPHeaderField:@"Content-Length"];
    
    [request setHTTPBody:data];
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:nil delegateQueue:nil];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completionHandler(error, nil);
        } else {
            // The data we recieve needs to be unzipped, as it is gzip'd.
            data = [data gunzippedData];
            
            NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
            
            // Hit the completion handler.
            completionHandler(nil, plist);
        }
    }];
    [task resume];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Sign-In methods.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// private sign in to this class.
+ (void)_signInWithUsername:(NSString *)username password:(NSString *)password andCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://idmsa.apple.com/IDMSWebAuth/clientDAW.cgi"]];
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
    [request setValue:@"en-us" forHTTPHeaderField:@"Accept-Language"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
    
    NSString *postString = [NSString stringWithFormat:@"appIdKey=ba2ec180e6ca6e6c6a542255453b24d6e6e5b2be0cc48bc1b0d8ad64cfe0228f&userLocale=en_US&protocolVersion=A1234&appleId=%@&password=%@&format=plist", [self _urlEncodeString:username], [self _urlEncodeString:password]];
    
    [request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:nil delegateQueue:nil];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {        
        if (error) {
            completionHandler(error, nil);
        } else {
            NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
            
            NSString *myacinfo = [plist objectForKey:@"myacinfo"];
            if (myacinfo) {
                acinfo = myacinfo;
            }
            
            // Hit the completion handler. It is possible that this request resulted in a need for 2FA.
            completionHandler(nil, plist);
        }
    }];
    [task resume];
}

+ (void)signInWithUsername:(NSString *)username password:(NSString *)password andCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    [self _signInWithUsername:username password:password andCompletionHandler:^(NSError *error, NSDictionary *plist) {
        if (error) {
            // Oh no.
            NSLog(@"Error on sign-in! %@", error);
            completionHandler(error, plist);
            return;
        }
        
        NSString *userString = [plist objectForKey:@"userString"];
        NSString *reason = @"";
        
        NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
        [resultDictionary setObject:userString forKey:@"userString"];
        
        if ((!userString || [userString isEqualToString:@""]) && plist) {
            // We now have been authenticated most likely.
            reason = @"authenticated";
            
        } else if (plist) {
            // Failure, but we have something useful.
            
            // -22938 => App Specific Pwd?
            // -20101 => incorrect credentials.
            
            NSString *resultCode = [plist objectForKey:@"resultCode"];
            
            if ([resultCode isEqualToString:@"-22938"] || [userString containsString:@"app-specific"]) {
                reason = @"appSpecificRequired";
            } else if ([resultCode isEqualToString:@"-20101"] || [resultCode isEqualToString:@"-1"]) {
                reason = @"incorrectCredentials";
            } else {
                reason = resultCode;
            }
        }
        
        [resultDictionary setObject:reason forKey:@"reason"];
        
        completionHandler(error, resultDictionary);
    }];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Team ID methods.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString*)currentTeamID {
    return _teamid;
}

+ (void)updateCurrentTeamIDWithTeamIDCheck:(NSString* (^)(NSArray*))teamIDCallback andCallback:(void (^)(NSError*, NSString *))completionHandler {
    // We also want to pull the Team ID for this user, rather than find it on installation.
    [EEAppleServices listTeamsWithCompletionHandler:^(NSError *error, NSDictionary *plist) {
        if (error) {
            
            // XXX: It is possible for a user to never have signed up for a development
            // account with Apple with their existing ID. Thus, we should hit here if
            // that's the case!
            
            _teamid = @"";
            completionHandler(error, @"");
            return;
        }
        
        NSArray *teams = [plist objectForKey:@"teams"];
        if (!teams) {
            completionHandler(error, @"");
            return;
        }
        
        NSString *teamId;
        
        // If there are multiple teams this user is in, request which one they want to use.
        if (teams.count > 1) {
            teamId = teamIDCallback(teams);
        } else if (teams.count == 1) {
            NSDictionary *onlyTeam = teams[0];
            teamId = [onlyTeam objectForKey:@"teamId"];
        } else {
            completionHandler(error, @"");
            return;
        }
        
        _teamid = teamId;
        
        completionHandler(error, _teamid);
    }];
}

+ (void)viewDeveloperWithCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/viewDeveloper.action?clientId=XABBG36SBA"]];
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
    [request setValue:@"en-us" forHTTPHeaderField:@"Accept-Language"];
    [request setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Content-Type"]; // Body is a plist.
    [request setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"7.0 (7A120f)" forHTTPHeaderField:@"X-Xcode-Version"];
    
    // The acinfo is set as a cookie for authentication purposes.
    [request setValue:[NSString stringWithFormat:@"myacinfo=%@", acinfo] forHTTPHeaderField:@"Cookie"];
    
    // Now, body.
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setObject:@"XABBG36SBA" forKey:@"clientId"];
    [dict setObject:acinfo forKey:@"myacinfo"];
    [dict setObject:@"QH65B2" forKey:@"protocolVersion"];
    [dict setObject:[[NSUUID UUID] UUIDString] forKey:@"requestId"];
    [dict setObject:@[@"en_US"] forKey:@"userLocale"];
    
    // We want this as an XML plist.
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    
    // Add content length too.
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)data.length] forHTTPHeaderField:@"Content-Length"];
    
    [request setHTTPBody:data];
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:nil delegateQueue:nil];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completionHandler(error, nil);
        } else {
            // The data we recieve needs to be unzipped, as it is gzip'd.
            data = [data gunzippedData];
            
            NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
            
            // Hit the completion handler.
            completionHandler(nil, plist);
        }
    }];
    [task resume];
}

+ (void)listTeamsWithCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/listTeams.action?clientId=XABBG36SBA"]];
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Accept"];
    [request setValue:@"en-us" forHTTPHeaderField:@"Accept-Language"];
    [request setValue:@"text/x-xml-plist" forHTTPHeaderField:@"Content-Type"]; // Body is a plist.
    [request setValue:@"Xcode" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"7.0 (7A120f)" forHTTPHeaderField:@"X-Xcode-Version"];
    
    // The acinfo is set as a cookie for authentication purposes.
    [request setValue:[NSString stringWithFormat:@"myacinfo=%@", acinfo] forHTTPHeaderField:@"Cookie"];
    
    // Now, body.
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setObject:@"XABBG36SBA" forKey:@"clientId"];
    [dict setObject:acinfo forKey:@"myacinfo"];
    [dict setObject:@"QH65B2" forKey:@"protocolVersion"];
    [dict setObject:[[NSUUID UUID] UUIDString] forKey:@"requestId"];
    [dict setObject:@[@"en_US"] forKey:@"userLocale"];
    
    // We want this as an XML plist.
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    
    // Add content length too.
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)data.length] forHTTPHeaderField:@"Content-Length"];
    
    [request setHTTPBody:data];
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:nil delegateQueue:nil];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completionHandler(error, nil);
        } else {
            // The data we recieve needs to be unzipped, as it is gzip'd.
            data = [data gunzippedData];
            
            NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
            
            // Hit the completion handler.
            completionHandler(nil, plist);
        }
    }];
    [task resume];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Device methods
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)addDevice:(NSString*)udid deviceName:(NSString*)name forTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:udid forKey:@"deviceNumber"];
    [extra setObject:name forKey:@"name"];
    
    [EEAppleServices _doActionWithName:@"addDevice.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

+ (void)listDevicesForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:@"500" forKey:@"pageSize"];
    [extra setObject:@"1" forKey:@"pageNumber"];
    [extra setObject:@"name=asc" forKey:@"sort"];
    [extra setObject:@"false" forKey:@"includeRemovedDevices"];
    
    [EEAppleServices _doActionWithName:@"listDevices.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Application ID methods.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)listAllApplicationsForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    
    [EEAppleServices _doActionWithName:@"listAppIds.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

+ (void)addApplicationId:(NSString*)applicationIdentifier name:(NSString*)applicationName enabledFeatures:(NSDictionary*)enabledFeatures teamID:(NSString*)teamID entitlements:(NSDictionary*)entitlements systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:applicationIdentifier forKey:@"identifier"];
    [extra setObject:applicationName forKey:@"name"];
    [extra setObject:@"explicit" forKey:@"type"];
    
    // Features - assume caller has correctly set "on", "off", "whatever"
    for (NSString *key in [enabledFeatures allKeys]) {
        [extra setObject:[enabledFeatures objectForKey:key] forKey:key];
    }

    [extra setObject:entitlements forKey:@"entitlements"];
    
    [EEAppleServices _doActionWithName:@"addAppId.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

+ (void)updateApplicationIdId:(NSString*)appIdId enabledFeatures:(NSDictionary*)enabledFeatures teamID:(NSString*)teamID entitlements:(NSDictionary*)entitlements systemType:(EESystemType)systemType  withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler; {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:appIdId forKey:@"appIdId"];
    [extra setObject:@"explicit" forKey:@"type"];
    
    // Features - assume caller has correctly set "on", "off", "whatever"
    for (NSString *key in [enabledFeatures allKeys]) {
        [extra setObject:[enabledFeatures objectForKey:key] forKey:key];
    }
    
    [extra setObject:entitlements forKey:@"entitlements"];
    
    [EEAppleServices _doActionWithName:@"updateAppId.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

+ (void)deleteApplicationIdId:(NSString*)appIdId teamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:appIdId forKey:@"appIdId"];
    
    [EEAppleServices _doActionWithName:@"deleteAppId.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

+ (void)listAllApplicationGroupsForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    // CHECKME: is this the right dictionary?
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    
    [EEAppleServices _doActionWithName:@"listApplicationGroups.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

+ (void)addApplicationGroupWithIdentifier:(NSString*)identifier andName:(NSString*)groupName forTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:identifier forKey:@"identifier"];
    [extra setObject:groupName forKey:@"name"];
    
    [EEAppleServices _doActionWithName:@"addApplicationGroup.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

+ (void)assignApplicationGroup:(NSString*)applicationGroup toApplicationIdId:(NSString*)appIdId teamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:appIdId forKey:@"appIdId"];
    [extra setObject:applicationGroup forKey:@"applicationGroups"];
    
    [EEAppleServices _doActionWithName:@"assignApplicationGroupToAppId.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Certificates methods.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)listAllDevelopmentCertificatesForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    
    [EEAppleServices _doActionWithName:@"listAllDevelopmentCerts.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

+ (void)listAllProvisioningProfilesForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    
    [EEAppleServices _doActionWithName:@"listProvisioningProfiles.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

+ (void)getProvisioningProfileForAppIdId:(NSString*)appIdId withTeamID:(NSString*)teamID systemType:(EESystemType)systemType andCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:appIdId forKey:@"appIdId"];
    
    [EEAppleServices _doActionWithName:@"downloadTeamProvisioningProfile.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

+ (void)deleteProvisioningProfileForApplication:(NSString*)applicationId andTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    [EEAppleServices listAllProvisioningProfilesForTeamID:teamID systemType:systemType withCompletionHandler:^(NSError *error, NSDictionary *plist) {
        if (error) {
            completionHandler(error, nil);
            return;
        }
        
        NSArray *provisioningProfiles = [plist objectForKey:@"provisioningProfiles"];
        
        // We want the provisioning profile that has an appId that matches our provided bundle identifier.
        // Then, we take it's provisioningProfileId.
        
        NSString *provisioningProfileId = @"";
        
        for (NSDictionary *profile in provisioningProfiles) {
            NSDictionary *appId = [profile objectForKey:@"appId"];
            
            // For whatever reason, Impactor/Extender will add some extra stuff to identifier.
            BOOL matches = [[appId objectForKey:@"identifier"] rangeOfString:applicationId].location != NSNotFound;
            
            if (matches) {                
                provisioningProfileId = [profile objectForKey:@"provisioningProfileId"];
                break;
            }
        }
        
        if (![provisioningProfileId isEqualToString:@""]) {
            
            // Onwards to deletion!
            
            NSMutableDictionary *extra = [NSMutableDictionary dictionary];
            [extra setObject:teamID forKey:@"teamId"];
            [extra setObject:provisioningProfileId forKey:@"provisioningProfileId"];
            
            [EEAppleServices _doActionWithName:@"deleteProvisioningProfile.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
        } else {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: NSLocalizedString(@"No provisioning profile contains the provided bundle identifier.", nil),
                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No provisioning profile contains the provided bundle identifier.", nil)
                                       };
            NSError *error = [NSError errorWithDomain:NSInvalidArgumentException
                                                 code:-1
                                             userInfo:userInfo];

            
            completionHandler(error, nil);
            return;
        }
    }];
}

+ (void)revokeCertificateForSerialNumber:(NSString*)serialNumber andTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:serialNumber forKey:@"serialNumber"];
    
    [EEAppleServices _doActionWithName:@"revokeDevelopmentCert.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

+ (void)submitCodeSigningRequestForTeamID:(NSString*)teamId machineName:(NSString*)machineName machineID:(NSString*)machineID codeSigningRequest:(NSData*)csr systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSString *stringifiedCSR = [[NSString alloc] initWithData:csr encoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamId forKey:@"teamId"];
    [extra setObject:stringifiedCSR forKey:@"csrContent"];
    [extra setObject:machineID forKey:@"machineId"];
    [extra setObject:machineName forKey:@"machineName"];
    
    [EEAppleServices _doActionWithName:@"submitDevelopmentCSR.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

@end
