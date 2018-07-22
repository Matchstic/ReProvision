//
//  EESigning.h
//  OpenExtenderTest
//
//  Created by Matt Clarke on 28/12/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
#include <string>
#endif

@interface EESigning : NSObject {
    NSData *_certificate;
    NSString *_privateKey;
    #ifdef __cplusplus
    std::string _PKCS12;
    #endif
}

+ (instancetype)signerWithCertificate:(NSData*)certificate privateKey:(NSString*)privateKey;

+ (NSDictionary*)updateEntitlementsForBinaryAtLocation:(NSString*)binaryLocation bundleIdentifier:(NSString*)bundleIdentifier teamID:(NSString*)teamid;

- (void)signBundleAtPath:(NSString*)absolutePath entitlements:(NSDictionary*)entitlements withCallback:(void (^)(BOOL, NSString*))completionHandler;

@end
