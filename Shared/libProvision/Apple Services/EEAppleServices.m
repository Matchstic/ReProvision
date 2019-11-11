//
//  EEAppleServices.m
//  Extender Installer
//
//  Created by Matt Clarke on 28/04/2017.
//
//

#import "EEAppleServices.h"
#import "NSData+GZIP.h"
static NSArray *acinfo = @"";
static NSString *_teamid = @"";
static AKAppleIDSession* appleIDSession = nil;
static NSURLCredential* cred = nil;
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
    NSString *os = (systemType==EESystemTypeUndefined)?@"":(systemType == EESystemTypeiOS || systemType == EESystemTypewatchOS ? @"ios/" : @"tvos/");
    NSString *urlStr = [NSString stringWithFormat:@"https://developerservices2.apple.com/services/QH65B2/%@%@?clientId=XABBG36SBA", os,action];
    
    NSLog(@"Request to URL: %@", urlStr);
    
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlStr]];
    request.HTTPMethod = @"POST";
    if(appleIDSession==nil){
        appleIDSession = [[AKAppleIDSession alloc] initWithIdentifier:@"com.apple.gs.xcode.auth"];
    }
    NSDictionary<NSString *, NSString *> *appleHeaders = [appleIDSession appleIDHeadersForRequest:request];
    AKDevice* currentDevice = [AKDevice currentDevice];
    NSDictionary<NSString *, NSString *> *httpHeaders = @{
                                                          @"Content-Type": @"text/x-xml-plist",
                                                          @"User-Agent": @"Xcode",
                                                          @"Accept": @"text/x-xml-plist",
                                                          @"Accept-Language": @"en-us",
                                                          @"Connection": @"keep-alive",
                                                          @"X-Xcode-Version": @"11.2 (11B52)",
                                                          @"X-Apple-I-Identity-Id": [[cred user] componentsSeparatedByString:@"|"][0],
                                                          @"X-Apple-GS-Token": [cred password],
                                                          @"X-Apple-App-Info": @"com.apple.gs.xcode.auth",
                                                          @"X-Mme-Device-Id": [currentDevice uniqueDeviceIdentifier],
                                                          @"X-MMe-Client-Info":[currentDevice serverFriendlyDescription]
                                                          };
    
    [httpHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
    [appleHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
    // Now, body.
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setObject:@"XABBG36SBA" forKey:@"clientId"];
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
        
    [request setHTTPBody:data];
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:nil delegateQueue:nil];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error||data==nil) {
            completionHandler(error, nil);
        } else {
            NSData* unpacked = [data isGzippedData]?[data gunzippedData]:data;
            NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:unpacked options:NSPropertyListImmutable format:nil error:nil];
            if(plist==nil) completionHandler(error,nil);
            // Hit the completion handler.
            completionHandler(nil, plist);
        }
    }];
    [task resume];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Sign-In methods.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)signInWithUsername:(NSString *)altDSID password:(NSString *)GSToken andCompletionHandler:(void (^)(NSError *, NSDictionary *,NSURLCredential*))completionHandler{

    cred = [[NSURLCredential alloc] initWithUser:[altDSID copy] password:[GSToken copy] persistence:NSURLCredentialPersistencePermanent];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/listTeams.action?clientId=XABBG36SBA"]];
        request.HTTPMethod = @"POST";
        
        NSMutableDictionary<NSString *, NSString *> *parameters = [@{
        @"clientId": @"XABBG36SBA",
        @"protocolVersion": @"QH65B2",
        @"requestId": [[[NSUUID UUID] UUIDString] uppercaseString],
        } mutableCopy];
        NSError *serializationError = nil;
        NSData *bodyData = [NSPropertyListSerialization dataWithPropertyList:parameters format:NSPropertyListXMLFormat_v1_0 options:0 error:&serializationError];
        if (bodyData == nil)
        {
            completionHandler(nil, nil,nil);
            return;
        }
        request.HTTPBody = bodyData;
        if(appleIDSession==nil){
            appleIDSession = [[AKAppleIDSession alloc] initWithIdentifier:@"com.apple.gs.xcode.auth"];
        }
        NSDictionary<NSString *, NSString *> *appleHeaders = [appleIDSession appleIDHeadersForRequest:request];
         AKDevice* currentDevice = [AKDevice currentDevice];
        NSDictionary<NSString *, NSString *> *httpHeaders = @{
                                                                 @"Content-Type": @"text/x-xml-plist",
                                                                 @"User-Agent": @"Xcode",
                                                                 @"Accept": @"text/x-xml-plist",
                                                                 @"Accept-Language": @"en-us",
                                                                 @"Connection": @"keep-alive",
                                                                 @"X-Xcode-Version": @"11.2 (11B52)",
                                                                 @"X-Apple-I-Identity-Id": [[cred user] componentsSeparatedByString:@"|"][0],
                                                                 @"X-Apple-GS-Token": [cred password],
                                                                 @"X-Apple-App-Info": @"com.apple.gs.xcode.auth",
                                                                 @"X-Mme-Device-Id": [currentDevice uniqueDeviceIdentifier],
                                                                 @"X-MMe-Client-Info":[currentDevice serverFriendlyDescription]
        };
        
        [httpHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            [request setValue:value forHTTPHeaderField:key];
        }];
        [appleHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            [request setValue:value forHTTPHeaderField:key];
        }];
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:nil delegateQueue:nil];
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable requestError) {
            if (data == nil)
            {
                completionHandler(requestError,nil,nil);
                return;
            }
            NSError *parseError = nil;
            NSMutableDictionary *plist = [[NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:&parseError] mutableCopy];
            if (plist == nil)
            {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:@{NSUnderlyingErrorKey: parseError}];
                completionHandler(error,nil,nil);
                return;
            }
            NSString *userString = [plist objectForKey:@"userString" ];
            NSString *reason = @"";
            
            NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
            
            if ((!userString || [userString isEqualToString:@""]) && plist) {
                // We now have been authenticated most likely.
                reason = @"authenticated";
                userString = @"";
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
            
            [resultDictionary setObject:userString forKey:@"userString"];
            [resultDictionary setObject:reason forKey:@"reason"];
            completionHandler(nil, resultDictionary,[cred copy]);
        }];
        
        [dataTask resume];
}
+ (void)signInWithViewController:(UIViewController*)viewController andCompletionHandler:(void (^)(NSError*, NSDictionary *,NSURLCredential*))completionHandler
{
    AKAppleIDAuthenticationInAppContext* context = [[AKAppleIDAuthenticationInAppContext alloc] init];
    [context setTitle:@"ReProvision"];
    [context setReason:@"Sign in to the account you used for Cydia Impactor"];
    [context setAuthenticationType:2];
    [context setServiceIdentifier:@"com.apple.gs.xcode.auth"];
    [context setServiceIdentifiers:[NSArray arrayWithObject:@"com.apple.gs.xcode.auth"]];
    context.presentingViewController = viewController;
    AKAppleIDAuthenticationController* controller = [[AKAppleIDAuthenticationController alloc] initWithIdentifier:nil daemonXPCEndpoint:nil];
    [controller authenticateWithContext:context completion:^(id arg1){
        if(arg1==nil){
            return;
        }
        
        NSString* AKUsername = [[arg1 objectForKey:@"AKUsername"] copy];
        NSDictionary* IDMSToken = [arg1 objectForKey:@"AKIDMSToken"];
        NSString* GSToken = [[IDMSToken objectForKey:@"com.apple.gs.xcode.auth"] copy];
        NSString* AKAltDSID = [[arg1 objectForKey:@"AKAltDSID"] copy];
        NSString* username = [[NSString alloc] initWithFormat:@"%@|%@",AKAltDSID,AKUsername];
        [self signInWithUsername:username password:GSToken andCompletionHandler:completionHandler];
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
    [self _doActionWithName:@"viewDeveloper.action" systemType:EESystemTypeUndefined extraDictionary:nil andCompletionHandler:^(NSError * error, NSDictionary *plist) {
        if (error) {
            completionHandler(error, nil);
        } else {
            // Hit the completion handler.
            completionHandler(nil, plist);
        }
    }];
}

+ (void)listTeamsWithCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
        
            
    [self _doActionWithName:@"listTeams.action" systemType:EESystemTypeUndefined extraDictionary:nil andCompletionHandler:^(NSError *error, NSDictionary *plist) {
        if (error) {
            completionHandler(error, nil);
        } else {
            // Hit the completion handler.
            completionHandler(nil, plist);
        }
    }];
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
