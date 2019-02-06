//
//  EESigning.m
//  OpenExtenderTest
//
//  Created by Matt Clarke on 28/12/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import "EESigning.h"
#include "ldid.hpp"

#include <stdio.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/pkcs12.h>
#include <openssl/err.h>

static auto dummy([](double) {});

@implementation EESigning

+ (instancetype)signerWithCertificate:(NSData*)certificate privateKey:(NSString*)privateKey {
    return [[EESigning alloc] initWithCertificate:certificate privateKey:privateKey];
}

- (instancetype)initWithCertificate:(NSData*)certificate privateKey:(NSString*)privateKey {
    self = [super init];
    
    if (self) {
        _certificate = certificate;
        _privateKey = privateKey;
        
        // Create a PKCS12 certificate from the private key and certificate. This is what ldid
        // accepts in Sign().
        // Effecctively, we're doing:
        // openssl pkcs12 -inkey key.pem -in certificate.pem -export -out certificate.p12 -CAfile caChain.pem -chain
        // Where key.pem == privateKey, certificate.pem == certificate, caChain.pem == apple-ios.pem
        
        // Create our PKCS12!
        _PKCS12 = [self _createPKCS12CertificateWithKey:privateKey certificate:certificate andCAChain:[self _loadCAChainFromDisk]];
        if (_PKCS12.size() == 0) {
            // Holy moly Batman.
        }
    }
    
    return self;
}

+ (NSDictionary*)updateEntitlementsForBinaryAtLocation:(NSString*)binaryLocation bundleIdentifier:(NSString*)bundleIdentifier teamID:(NSString*)teamid {
    
    NSMutableDictionary* plist = [NSMutableDictionary dictionary];
    
    NSLog(@"Loading entitlements for: '%@'", binaryLocation);
    
    // Make sure to pass in the entitlements already present, updating as needed.
    NSData *binaryData = [NSData dataWithContentsOfFile:binaryLocation];
    if (!binaryData || binaryData.length == 0) {
        return [NSDictionary dictionary];
    }
    
    // If entitlements are present, we MUST update the following keys first:
    // application-identifier -> <teamId>.<applicationIdentifier>
    // com.apple.developer.team-identifier -> <teamId>
    // keychain-access-groups -> array containing <teamId>.<applicationIdentifier>
    
    std::string entitlements = ldid::Analyze([binaryData bytes], (size_t)[binaryData length]);
    if (entitlements.length() > 0) {
        NSLog(@"Has entitlements in binary, so loading existing!");
        NSData* plistData = [NSData dataWithBytes:entitlements.data() length:entitlements.length()];
        
        NSError *error;
        NSPropertyListFormat format;
        plist = [[NSPropertyListSerialization propertyListWithData:plistData options:0 format:&format error:&error] mutableCopy];
    }
    
    [plist setValue:[NSString stringWithFormat:@"%@.%@", teamid, bundleIdentifier] forKey:@"application-identifier"];
    [plist setValue:teamid forKey:@"com.apple.developer.team-identifier"];
    
    NSMutableArray *keychainAccessGroups = [NSMutableArray array];
    
    NSString *applicationident = [NSString stringWithFormat:@"%@.*", teamid];
    [keychainAccessGroups addObject:applicationident];
    
    [plist setValue:keychainAccessGroups forKey:@"keychain-access-groups"];
    //[plist setValue:@YES forKey:@"get-task-allow"];
    
    return plist;
}

- (void)signBundleAtPath:(NSString*)absolutePath entitlements:(NSDictionary*)entitlements withCallback:(void (^)(BOOL, NSString*))completionHandler {
    
    // We request that ldid signs the bundle given, with our PKCS12 file so that it is validly codesigned.
    if (_PKCS12.size() == 0) {
        completionHandler(NO, @"No valid PKCS12 certificate is available to use for signing.");
        return;
    }
    
    NSError *error;
    NSMutableData* exportedPlist = [[NSPropertyListSerialization dataWithPropertyList:entitlements format:NSPropertyListXMLFormat_v1_0 options:0 error:&error] mutableCopy];
    [exportedPlist appendBytes:"\x0" length:1];
    
    std::string entitlementsString = (char*)[exportedPlist bytes];
    NSLog(@"Entitlements are:\n%s", entitlementsString.c_str());
    
    std::string requirementsString = [self _createRequirementsBlob:CFSTR("anchor apple generic")];
    //std::string requirementsString = "";
    
    // We can now sign!

    ldid::DiskFolder folder([[absolutePath copy] cStringUsingEncoding:NSUTF8StringEncoding]);
    ldid::Bundle outputBundle = Sign("", folder, _PKCS12, requirementsString, ldid::fun([&](const std::string &, const std::string &) -> std::string { return entitlementsString; }), ldid::fun([&](const std::string &) {}), ldid::fun(dummy));
    
    // TODO: Handle errors!
    
    completionHandler(YES, @"");
}

- (X509 *)_loadCAChainFromDisk {
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"apple-ios-new" ofType:@"pem"];
    
    NSLog(@"Loading CA chain from '%@'", filepath);
    
    NSString *contents = [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:nil];
    
    BIO *bio = BIO_new(BIO_s_mem());
    BIO_puts(bio, [contents cStringUsingEncoding:NSUTF8StringEncoding]);
    
    X509 *cert = PEM_read_bio_X509(bio, NULL, NULL, NULL);
    if (!cert) {
        NSLog(@"Failed to load CA chain.");
        @throw [NSException exceptionWithName:@"libProvisionSigningException" reason:@"Could not load CA chain from disk!" userInfo:nil];
    }
    
    return cert;
}

- (std::string)_createPKCS12CertificateWithKey:(NSString*)key certificate:(NSData*)certificate andCAChain:(X509 *)chain {
    
    // Load root CA
    NSString *rootCAFilepath = [[NSBundle mainBundle] pathForResource:@"root" ofType:@"pem"];
    
    NSString *rootCAContents = [NSString stringWithContentsOfFile:rootCAFilepath encoding:NSUTF8StringEncoding error:nil];
    
    BIO *rootCABio = BIO_new(BIO_s_mem());
    BIO_puts(rootCABio, [rootCAContents cStringUsingEncoding:NSUTF8StringEncoding]);
    
    X509 *rootCA = PEM_read_bio_X509(rootCABio, NULL, NULL, NULL);
    if (!rootCA) {
        NSLog(@"Failed to load root CA.");
        @throw [NSException exceptionWithName:@"libProvisionSigningException" reason:@"Could not load CA root from disk!" userInfo:nil];
    }
    
    // Code utilised from: http://fm4dd.com/openssl/pkcs12test.htm
    
    X509           *cert, *cacert;
    STACK_OF(X509) *cacertstack;
    PKCS12         *pkcs12bundle;
    EVP_PKEY       *cert_privkey;
    BIO            *bio_privkey = NULL, *bio_certificate = NULL, *bio_pkcs12 = NULL;
    int            bytes = 0;
    char           *data = NULL;
    long           len = 0;
    int            error = 0;
    
    /* ------------------------------------------------------------ *
     * 1.) These function calls are essential to make PEM_read and  *
     *     other openssl functions work.                            *
     * ------------------------------------------------------------ */
    OpenSSL_add_all_algorithms();
    ERR_load_crypto_strings();
    
    /*--------------------------------------------------------------*
     * 2.) we load the certificates private key                     *
     *    ( for this, it has no password )                     *
     *--------------------------------------------------------------*/
    
    bio_privkey = BIO_new(BIO_s_mem());
    BIO_puts(bio_privkey, [key cStringUsingEncoding:NSUTF8StringEncoding]);
    
    if (!(cert_privkey = PEM_read_bio_PrivateKey(bio_privkey, NULL, NULL, NULL))) {
        NSLog(@"Error loading certificate private key content.");
        error = -1;
    }
    
    /*--------------------------------------------------------------*
     * 3.) we load the corresponding certificate                    *
     *--------------------------------------------------------------*/
    
    const unsigned char *input = (unsigned char*)[certificate bytes];
    cert = d2i_X509(NULL, &input, (int)[certificate length]);
    if (!cert) {
        NSLog(@"Error loading cert into memory.");
        error = -1;
    }
    
    /*--------------------------------------------------------------*
     * 4.) we load the CA certificate who signed it                 *
     *--------------------------------------------------------------*/
    
    cacert = chain;
    
    /*--------------------------------------------------------------*
     * 5.) we load the CA certificate on the stack                  *
     *--------------------------------------------------------------*/
    
    if ((cacertstack = sk_X509_new_null()) == NULL) {
        NSLog(@"Error creating STACK_OF(X509) structure.");
        error = -1;
    }
    
    sk_X509_push(cacertstack, rootCA);
    sk_X509_push(cacertstack, cacert);
    
    /*--------------------------------------------------------------*
     * 6.) we create the PKCS12 structure and fill it with our data *
     *--------------------------------------------------------------*/
    
    if ((pkcs12bundle = PKCS12_new()) == NULL) {
        NSLog(@"Error creating PKCS12 structure.");
        error = -1;
    }
    
    /* values of zero use the openssl default values */
    pkcs12bundle = PKCS12_create(
                                 (char*)"",       // We give a password of "" here as ldid expects that
                                 (char*)"ReProvision",  // friendly certname
                                 cert_privkey,// the certificate private key
                                 cert,        // the main certificate
                                 cacertstack, // stack of CA cert chain
                                 0,           // int nid_key (default 3DES)
                                 0,           // int nid_cert (40bitRC2)
                                 0,           // int iter (default 2048)
                                 0,           // int mac_iter (default 1)
                                 0            // int keytype (default no flag)
                                 );
    if (pkcs12bundle == NULL) {
        NSLog(@"Error generating a valid PKCS12 certificate.");
        error = -1;
    }
    
    /*--------------------------------------------------------------*
     * 7.) we write the PKCS12 structure out to NSData              *
     *--------------------------------------------------------------*/
    
    bio_pkcs12 = BIO_new(BIO_s_mem());
    bytes = i2d_PKCS12_bio(bio_pkcs12, pkcs12bundle);
    
    if (bytes <= 0) {
        NSLog(@"Error writing PKCS12 certificate.");
        error = -1;
    }
    
    len = BIO_get_mem_data(bio_pkcs12, &data);
    NSData *result = [NSData dataWithBytes:data length:len];
    
    /*--------------------------------------------------------------*
     * 8.) we are done, let's clean up                              *
     *--------------------------------------------------------------*/
    
    X509_free(cert);
    X509_free(cacert);
    sk_X509_free(cacertstack);
    PKCS12_free(pkcs12bundle);
    
    BIO_free_all(bio_pkcs12);
    BIO_free_all(bio_certificate);
    BIO_free_all(bio_privkey);
    
    if (error == -1) {
        std::string s("");
        return s;
    } else {
        std::string s(reinterpret_cast<char const*>([result bytes]), [result length]);
        return s;
    }
}

- (std::string)_createRequirementsBlob:(CFStringRef)string {
    SecRequirementRef requirementRef = NULL;
    OSStatus status = SecRequirementCreateWithString(string, kSecCSDefaultFlags, &requirementRef);
    
    if (status != noErr) {
        NSLog(@"Error: Failed to create requirements! %d", status);
        
        return "";
    }
    
    std::string result = "";
    CFDataRef data;
    status = SecRequirementCopyData(requirementRef, kSecCSDefaultFlags, &data);
    
    if (status != noErr) {
        NSLog(@"Error: Failed to copy requirements! %d", status);
        
        return "";
    }
    
    auto buffer = reinterpret_cast<const char*>(CFDataGetBytePtr(data));
    auto buffer_length = static_cast<std::size_t>(CFDataGetLength(data));
    result = std::string(buffer, buffer_length - 1);
    
    //free req reference
    if (requirementRef != NULL) {
        CFRelease(requirementRef);
        requirementRef = NULL;
    }
    
    return result;
}

@end
