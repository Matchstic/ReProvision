//
//  EEAppleServices.m
//  Extender Installer
//
//  Created by Matt Clarke on 28/04/2017.
//
//

#import "EEAppleServices.h"
#import "NSData+GZIP.h"
#import "RPVAuthentication.h"
#import "AuthKit.h"

@interface EEAppleServices ()

@property (nonatomic, strong) NSString *teamid;
@property (nonatomic, strong) NSURLCredential* credentials;
@property (nonatomic, strong) RPVAuthentication *authentication;

@end

@implementation EEAppleServices

+ (instancetype)sharedInstance {
    static EEAppleServices *sharedInstance = nil;
     static dispatch_once_t onceToken;

     dispatch_once(&onceToken, ^{
         sharedInstance = [[EEAppleServices alloc] init];
     });
     return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.teamid = @"";
        self.authentication = [[RPVAuthentication alloc] init];
    }
    
    return self;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Private methods.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSMutableURLRequest*)populateHeaders:(NSMutableURLRequest*)request {
    
    NSDictionary<NSString *, NSString *> *appleHeaders = [self.authentication appleIDHeadersForRequest:request];
    AKDevice* currentDevice = [AKDevice currentDevice];
    NSDictionary<NSString *, NSString *> *httpHeaders = @{
        @"Content-Type": @"text/x-xml-plist",
        @"User-Agent": @"Xcode",
        @"Accept": @"text/x-xml-plist",
        @"Accept-Language": @"en-us",
        @"Connection": @"keep-alive",
        @"X-Xcode-Version": @"11.2 (11B52)",
        @"X-Apple-I-Identity-Id": [[self.credentials user] componentsSeparatedByString:@"|"][0],
        @"X-Apple-GS-Token": [self.credentials password],
        @"X-Mme-Device-Id": [currentDevice uniqueDeviceIdentifier],
    };
    
    [httpHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
    
    [appleHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
    
    [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        NSLog(@"%@: %@", key, value);
    }];
    
    return request;
}

- (void)_doActionWithName:(NSString*)action systemType:(EESystemType)systemType extraDictionary:(NSDictionary*)extra andCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSString *os = @"";
    
    if (systemType != EESystemTypeUndefined)
        os = systemType == EESystemTypeiOS || systemType == EESystemTypewatchOS ? @"ios/" : @"tvos/";
    
    NSString *urlStr = [NSString stringWithFormat:@"https://developerservices2.apple.com/services/QH65B2/%@%@?clientId=XABBG36SBA", os,action];
    
    NSLog(@"Request to URL: %@", urlStr);
    
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlStr]];
    request.HTTPMethod = @"POST";
    
    request = [self populateHeaders:request];
    
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
        if (error || !data) {
            completionHandler(error, nil);
        } else {
            NSData* unpacked = [data isGzippedData] ? [data gunzippedData] : data;
            NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:unpacked options:NSPropertyListImmutable format:nil error:nil];
            
            if (!plist)
                completionHandler(error,nil);
            else
                // Hit the completion handler.
                completionHandler(nil, plist);
        }
    }];
    [task resume];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Sign-In methods.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)ensureSessionWithIdentity:(NSString*)identity gsToken:(NSString*)token andCompletionHandler:(void (^)(NSError *error, NSDictionary *plist))completionHandler {
    
    self.credentials = [[NSURLCredential alloc] initWithUser:identity password:token persistence:NSURLCredentialPersistencePermanent];
    
    // TODO: Validate credentials
    
    NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
    [resultDictionary setObject:@"authenticated" forKey:@"reason"];
    [resultDictionary setObject:@"" forKey:@"userString"];
    
    completionHandler(nil, resultDictionary);
}

- (void)signInWithUsername:(NSString *)username password:(NSString *)password andCompletionHandler:(void (^)(NSError *, NSDictionary *, NSURLCredential*))completionHandler {
    
    [self.authentication authenticateWithUsername:username password:password withCompletion:^(NSError *error, NSString *userIdentity, NSString *gsToken) {
        
        if (error) {
            NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
            
            if (error.code == -20101 || error.code == -22406) {
                [resultDictionary setObject:@"Your Apple ID or password is incorrect. App-specific passwords are not supported." forKey:@"userString"];
                [resultDictionary setObject:@"incorrectCredentials" forKey:@"reason"];
            } else if (error.code == 500) { // Internal error
                [resultDictionary setObject:error.localizedDescription forKey:@"userString"];
                [resultDictionary setObject:@"incorrectCredentials" forKey:@"reason"];
            } else if (error.code == -22938) {
                [resultDictionary setObject:@"2FA code is required" forKey:@"userString"];
                [resultDictionary setObject:@"appSpecificRequired" forKey:@"reason"];
            } else {
                [resultDictionary setObject:[NSString stringWithFormat:@"Unknown error occurred (%ld)", (long)error.code] forKey:@"userString"];
                [resultDictionary setObject:@"incorrectCredentials" forKey:@"reason"];
            }
            
            completionHandler(nil, resultDictionary, nil);
            
            return;
        }
        
        self.credentials = [[NSURLCredential alloc] initWithUser:userIdentity password:gsToken persistence:NSURLCredentialPersistencePermanent];
        
        // Do a request to listTeams.action to check that the user is a member of a team
        [self listTeamsWithCompletionHandler:^(NSError *error, NSDictionary *plist) {
            NSArray *teams = [plist objectForKey:@"teams"];
            
            if (!teams) {
                // Error of some kind?
                // TODO: HANDLE ME
                
                completionHandler(error, plist, nil);
                return;
            }
            
            NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
            
            [resultDictionary setObject:@"" forKey:@"userString"];
            [resultDictionary setObject:@"authenticated" forKey:@"reason"];
            
            completionHandler(nil, resultDictionary, self.credentials);
        }];
    }];
}

- (void)validateLoginCode:(long long)code andCompletionHandler:(void (^)(NSError*, NSDictionary*, NSURLCredential*))completionHandler {
    NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
    [resultDictionary setObject:@"2FA codes are not yet supported" forKey:@"userString"];
    [resultDictionary setObject:@"incorrectCredentials" forKey:@"reason"];
    
    completionHandler(nil, resultDictionary, nil);
    
    /*[self.authentication validateLoginCode:code withCompletion:^(NSError *error, NSString *userIdentity, NSString *gsToken) {
        if (error) {
            NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
            
            if (error.code == -7006 || error.code == -7027 || error.code == -20101) {
                [resultDictionary setObject:@"Your Apple ID or password is incorrect" forKey:@"userString"];
                [resultDictionary setObject:@"incorrectCredentials" forKey:@"reason"];
            } else {
                [resultDictionary setObject:@"Unknown error occurred" forKey:@"userString"];
                [resultDictionary setObject:@"incorrectCredentials" forKey:@"reason"];
            }
            
            completionHandler(nil, resultDictionary, nil);
            
            return;
        }
        
        self.credentials = [[NSURLCredential alloc] initWithUser:userIdentity password:gsToken persistence:NSURLCredentialPersistencePermanent];
        
        // Do a request to listTeams.action to check that the user is a member of a team
        [self listTeamsWithCompletionHandler:^(NSError *error, NSDictionary *plist) {
            NSArray *teams = [plist objectForKey:@"teams"];
            
            if (!teams) {
                // Error of some kind?
                // TODO: HANDLE ME
                
                completionHandler(error, plist, nil);
                return;
            }
            
            NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
            
            [resultDictionary setObject:@"" forKey:@"userString"];
            [resultDictionary setObject:@"authenticated" forKey:@"reason"];
            
            completionHandler(nil, resultDictionary, self.credentials);
        }];
    }];*/
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Team ID methods.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString*)currentTeamID {
    return self.teamid;
}

- (void)updateCurrentTeamIDWithTeamIDCheck:(NSString* (^)(NSArray*))teamIDCallback andCallback:(void (^)(NSError*, NSString *))completionHandler {
    // We also want to pull the Team ID for this user, rather than find it on installation.
    [self listTeamsWithCompletionHandler:^(NSError *error, NSDictionary *plist) {
        if (error) {
            
            // XXX: It is possible for a user to never have signed up for a development
            // account with Apple with their existing ID. Thus, we should hit here if
            // that's the case!
            
            self.teamid = @"";
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
        
        self.teamid = teamId;
        
        completionHandler(error, self.teamid);
    }];
}

- (void)viewDeveloperWithCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    [self _doActionWithName:@"viewDeveloper.action" systemType:EESystemTypeUndefined extraDictionary:nil andCompletionHandler:^(NSError * error, NSDictionary *plist) {
        if (error) {
            completionHandler(error, nil);
        } else {
            // Hit the completion handler.
            completionHandler(nil, plist);
        }
    }];
}

- (void)listTeamsWithCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
        
            
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

- (void)addDevice:(NSString*)udid deviceName:(NSString*)name forTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:udid forKey:@"deviceNumber"];
    [extra setObject:name forKey:@"name"];
    
    [self _doActionWithName:@"addDevice.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

- (void)listDevicesForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:@"500" forKey:@"pageSize"];
    [extra setObject:@"1" forKey:@"pageNumber"];
    [extra setObject:@"name=asc" forKey:@"sort"];
    [extra setObject:@"false" forKey:@"includeRemovedDevices"];
    
    [self _doActionWithName:@"listDevices.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Application ID methods.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)listAllApplicationsForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    
    [self _doActionWithName:@"listAppIds.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

- (void)addApplicationId:(NSString*)applicationIdentifier name:(NSString*)applicationName enabledFeatures:(NSDictionary*)enabledFeatures teamID:(NSString*)teamID entitlements:(NSDictionary*)entitlements systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
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
    
    [self _doActionWithName:@"addAppId.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

- (void)updateApplicationIdId:(NSString*)appIdId enabledFeatures:(NSDictionary*)enabledFeatures teamID:(NSString*)teamID entitlements:(NSDictionary*)entitlements systemType:(EESystemType)systemType  withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler; {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:appIdId forKey:@"appIdId"];
    [extra setObject:@"explicit" forKey:@"type"];
    
    // Features - assume caller has correctly set "on", "off", "whatever"
    for (NSString *key in [enabledFeatures allKeys]) {
        [extra setObject:[enabledFeatures objectForKey:key] forKey:key];
    }
    
    [extra setObject:entitlements forKey:@"entitlements"];
    
    [self _doActionWithName:@"updateAppId.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

- (void)deleteApplicationIdId:(NSString*)appIdId teamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:appIdId forKey:@"appIdId"];
    
    [self _doActionWithName:@"deleteAppId.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

- (void)listAllApplicationGroupsForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    // CHECKME: is this the right dictionary?
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    
    [self _doActionWithName:@"listApplicationGroups.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

- (void)addApplicationGroupWithIdentifier:(NSString*)identifier andName:(NSString*)groupName forTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:identifier forKey:@"identifier"];
    [extra setObject:groupName forKey:@"name"];
    
    [self _doActionWithName:@"addApplicationGroup.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

- (void)assignApplicationGroup:(NSString*)applicationGroup toApplicationIdId:(NSString*)appIdId teamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:appIdId forKey:@"appIdId"];
    [extra setObject:applicationGroup forKey:@"applicationGroups"];
    
    [self _doActionWithName:@"assignApplicationGroupToAppId.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Certificates methods.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)listAllDevelopmentCertificatesForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    
    [self _doActionWithName:@"listAllDevelopmentCerts.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

- (void)listAllProvisioningProfilesForTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    
    [self _doActionWithName:@"listProvisioningProfiles.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

- (void)getProvisioningProfileForAppIdId:(NSString*)appIdId withTeamID:(NSString*)teamID systemType:(EESystemType)systemType andCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:appIdId forKey:@"appIdId"];
    
    [self _doActionWithName:@"downloadTeamProvisioningProfile.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

- (void)deleteProvisioningProfileForApplication:(NSString*)applicationId andTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    [self listAllProvisioningProfilesForTeamID:teamID systemType:systemType withCompletionHandler:^(NSError *error, NSDictionary *plist) {
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
            
            [self _doActionWithName:@"deleteProvisioningProfile.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
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

- (void)revokeCertificateForSerialNumber:(NSString*)serialNumber andTeamID:(NSString*)teamID systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamID forKey:@"teamId"];
    [extra setObject:serialNumber forKey:@"serialNumber"];
    
    [self _doActionWithName:@"revokeDevelopmentCert.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

- (void)submitCodeSigningRequestForTeamID:(NSString*)teamId machineName:(NSString*)machineName machineID:(NSString*)machineID codeSigningRequest:(NSData*)csr systemType:(EESystemType)systemType withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
    NSString *stringifiedCSR = [[NSString alloc] initWithData:csr encoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [extra setObject:teamId forKey:@"teamId"];
    [extra setObject:stringifiedCSR forKey:@"csrContent"];
    [extra setObject:machineID forKey:@"machineId"];
    [extra setObject:machineName forKey:@"machineName"];
    
    [self _doActionWithName:@"submitDevelopmentCSR.action" systemType:systemType extraDictionary:extra andCompletionHandler:completionHandler];
}

@end
