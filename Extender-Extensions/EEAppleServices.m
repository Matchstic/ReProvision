//
//  EEAppleServices.m
//  Extender Installer
//
//  Created by Matt Clarke on 28/04/2017.
//
//

#import "EEAppleServices.h"
#import "NSData+GZIP.h"

static NSString *acinfo;

@implementation EEAppleServices

// From: http://stackoverflow.com/a/8088484
+ (NSString*)_urlEncodeString:(NSString*)string {
    /*NSMutableString *output = [NSMutableString string];
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
    return output;*/
    
    return [string stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
}

+ (void)signInWithUsername:(NSString *)username password:(NSString *)password andCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    
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

+ (void)listAllDevelopmentCertificatesForTeamID:(NSString*)teamID withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/ios/listAllDevelopmentCerts.action?clientId=XABBG36SBA"]];
    
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
    [dict setObject:@"ios" forKey:@"DTDK_Platform"];
    [dict setObject:teamID forKey:@"teamId"];
    
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

+ (void)revokeCertificateForSerialNumber:(NSString*)serialNumber andTeamID:(NSString*)teamID withCompletionHandler:(void (^)(NSError*, NSDictionary *))completionHandler {
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://developerservices2.apple.com/services/QH65B2/ios/revokeDevelopmentCert.action?clientId=XABBG36SBA"]];
    
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
    [dict setObject:@"ios" forKey:@"DTDK_Platform"];
    [dict setObject:teamID forKey:@"teamId"];
    [dict setObject:serialNumber forKey:@"serialNumber"];
    
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

@end
