//
//  RPVLoginImpl.cpp
//  iOS
//
//  Created by Kabir Oberai on 11/11/19.
//  Adapted by Matt Clarke on 24/11/19.
//

#import "RPVLoginImpl.h"

#import <corecrypto/ccsrp.h>
#import <corecrypto/ccdrbg.h>
#import <corecrypto/ccsrp_gp.h>
#import <corecrypto/ccdigest.h>
#import <corecrypto/ccsha2.h>
#import <corecrypto/ccpbkdf2.h>
#import <corecrypto/cchmac.h>
#import <corecrypto/ccaes.h>
#import <corecrypto/ccpad.h>
#import <corecrypto/ccrng_system.h>

#import <dlfcn.h>

#define DEBUG 1

struct ccrng_state *ccDRBGGetRngState(void);

@interface AKAppleIDSession : NSObject
- (AKAppleIDSession *)initWithIdentifier:(NSString *)identifier;
- (NSDictionary *)appleIDHeadersForRequest:(NSURLRequest *)request;
@end

@interface AKDevice : NSObject
+ (AKDevice *)currentDevice;
- (NSString *)uniqueDeviceIdentifier;
- (NSString *)MLBSerialNumber;
- (NSString *)ROMAddress;
- (NSString *)serialNumber;
@end

static void writeToLogFile(const char *string) {
#if DEBUG
    NSString *txtFileName = @"/var/mobile/Documents/ReProvisionDebug.txt";
    NSString *final = [NSString stringWithFormat:@"(%@) %s\n", [NSDate date], string];
     
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:txtFileName];
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[final dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    } else {
        [final writeToFile:txtFileName
                atomically:NO
                  encoding:NSStringEncodingConversionAllowLossy
                     error:nil];
    }
#endif
}

OS_FORMAT_PRINTF(1, 2)
static void log_error(const char *format, ...) {
    va_list args;
    va_start(args, format);
    char *str = NULL;
    vasprintf(&str, format, args);
    va_end(args);

    NSLog(@"[ERROR] %s", str);
    writeToLogFile(str);

    free(str);
}

OS_FORMAT_PRINTF(1, 2)
static void log_debug(const char *format, ...) {
#if DEBUG
    va_list args;
    va_start(args, format);
    char *str = NULL;
    vasprintf(&str, format, args);
    va_end(args);

    NSLog(@"[DEBUG] %s", str);
    writeToLogFile(str);

    free(str);
#endif
}

static const char hexchars[] = "0123456789abcdef";

// AppleIDAuthSupport`AppleIDAuthSupportPBKDF2SRP
static NSData *PBKDF2SRP(const struct ccdigest_info *di_info, BOOL notS2K, NSString *password, NSData *salt, NSNumber *iterations) {
    const struct ccdigest_info *password_di_info = ccsha256_di();
    char digest_raw[password_di_info->output_size];
    const char *passwordUTF8 = password.UTF8String;
    ccdigest(password_di_info, strlen(passwordUTF8), passwordUTF8, digest_raw);

    size_t final_digest_len = password_di_info->output_size * (notS2K ? 2 : 1);
    char digest[final_digest_len];

    if (notS2K) {
        // s2k_fo passes a hex string version of the bytes instead
        for (size_t i = 0; i < password_di_info->output_size; i++) {
            char byte = digest_raw[i];
            digest[i * 2 + 0] = hexchars[(byte >> 4) & 0x0F];
            digest[i * 2 + 1] = hexchars[(byte >> 0) & 0x0F];
        }
    } else {
        memcpy(digest, digest_raw, final_digest_len);
    }

    NSMutableData *data = [NSMutableData dataWithLength:di_info->output_size];
    int result = ccpbkdf2_hmac(di_info,
                               final_digest_len, digest,
                               salt.length, salt.bytes,
                               iterations.integerValue,
                               di_info->output_size, data.mutableBytes);
    if (result != 0) return nil;
    return data;
}

// AppleIDAuthSupport`addStringToNegProt
static void addStringToNegProt(const struct ccdigest_info *di_info, struct ccdigest_ctx *di_ctx, const char *str) {
    ccdigest_update(di_info, di_ctx, strlen(str), str);
}

// AppleIDAuthSupport`addDataToNegProt
static void addDataToNegProt(const struct ccdigest_info *di_info, struct ccdigest_ctx *di_ctx, NSData *data) {
    uint32_t data_len = (uint32_t)data.length; // 4 bytes for length
    ccdigest_update(di_info, di_ctx, sizeof(data_len), &data_len);
    ccdigest_update(di_info, di_ctx, data_len, data.bytes);
}

// AppleIDAuthSupport`SRPCreateSessionKey
static NSData *createSessionKey(ccsrp_ctx_t srp_ctx, const char *key_name) {
    size_t key_len;
    const void *session_key = ccsrp_get_session_key(srp_ctx, &key_len);
    const struct ccdigest_info *di_info = ccsha256_di();
    size_t hmac_len = di_info->output_size;
    unsigned char hmac_bytes[hmac_len];
    cchmac(di_info, key_len, session_key, strlen(key_name), key_name, hmac_bytes);
    return [NSData dataWithBytes:hmac_bytes length:hmac_len];
}

// AppleIDAuthSupport`CreateDecryptedData
static NSData *decryptCBC(ccsrp_ctx_t srp_ctx, NSData *spd) {
    NSData *extraDataKey = createSessionKey(srp_ctx, "extra data key:");
    NSData *extraDataIV = createSessionKey(srp_ctx, "extra data iv:");

    NSMutableData *decrypted = [NSMutableData dataWithLength:spd.length];

    const struct ccmode_cbc *decrypt_mode = ccaes_cbc_decrypt_mode();
    cccbc_iv iv[decrypt_mode->block_size];
    if (extraDataIV.bytes) {
        memcpy(iv, extraDataIV.bytes, decrypt_mode->block_size);
    } else {
        bzero(iv, decrypt_mode->block_size);
    }

    cccbc_ctx ctx_buf[decrypt_mode->size];
    decrypt_mode->init(decrypt_mode, ctx_buf, extraDataKey.length, extraDataKey.bytes);

    size_t len = ccpad_pkcs7_decrypt(decrypt_mode, ctx_buf, iv, spd.length, spd.bytes, decrypted.mutableBytes);
    if (len > spd.length) {
        log_error("decrypted len > spd len");
        return nil;
    }

    return decrypted;
}

// AppleIDAuthSupport`_AppleIDAuthSupportCreateDecryptedData
static NSData *decryptGCM(NSData *sk, NSData *encrypted) {
    const struct ccmode_gcm *decrypt_mode = ccaes_gcm_decrypt_mode();
    ccgcm_ctx gcm_ctx[decrypt_mode->size];
    decrypt_mode->init(decrypt_mode, gcm_ctx, sk.length, sk.bytes);
    if (encrypted.length < 35) {
        log_error("Encrypted token too short!");
        return nil;
    }
    if (cc_cmp_safe(3, encrypted.bytes, "XYZ")) {
        log_error("Encrypted token wrong version!");
        return nil;
    }
    decrypt_mode->set_iv(gcm_ctx, 16, (unsigned char*)encrypted.bytes + 3);
    decrypt_mode->gmac(gcm_ctx, 3, encrypted.bytes);

    size_t decrypted_len = encrypted.length - 35;
    NSMutableData *decrypted = [NSMutableData dataWithLength:decrypted_len];
    decrypt_mode->gcm(gcm_ctx, decrypted_len, (unsigned char*)encrypted.bytes + 16 + 3, decrypted.mutableBytes);

    char tag[16];
    decrypt_mode->finalize(gcm_ctx, 16, tag);
    if (cc_cmp_safe(16, (unsigned char*)encrypted.bytes + decrypted_len + 19, tag)) {
        log_error("Invalid tag version");
        return nil;
    }

    return decrypted;
}

// AppleIDAuthSupport`cfHMAC
static void update_hmac(const struct ccdigest_info *di_info, struct cchmac_ctx *hmac_ctx, id value) {
    if ([value isKindOfClass:NSArray.class]) {
        NSArray<NSString *> *apps = value;
        for (NSString *app in apps) {
            update_hmac(di_info, hmac_ctx, app);
        }
    } else if ([value isKindOfClass:NSString.class]) {
        NSString *app = value;
        const char *appUTF8 = app.UTF8String;
        cchmac_update(di_info, hmac_ctx, strlen(appUTF8), appUTF8);
    } else if ([value isKindOfClass:NSData.class]) {
        NSData *appData = value;
        cchmac_update(di_info, hmac_ctx, appData.length, appData.bytes);
    } else {
        log_error("Invalid hmac value passed: %s", [value description].UTF8String);
    }
}

// AppleIDAuthSupport`CreateAppTokensChecksum
static NSData *createAppTokensChecksum(NSData *sk, NSString *adsid, NSArray<NSString *> *apps) {
    const struct ccdigest_info *di_info = ccsha256_di();
    size_t hmac_size = cchmac_di_size(di_info);
    struct cchmac_ctx hmac_ctx[hmac_size];
    cchmac_init(di_info, hmac_ctx, sk.length, sk.bytes);

    const char *key = "apptokens";
    cchmac_update(di_info, hmac_ctx, strlen(key), key);

    const char *adsidUTF8 = adsid.UTF8String;
    cchmac_update(di_info, hmac_ctx, strlen(adsidUTF8), adsidUTF8);

    update_hmac(di_info, hmac_ctx, apps);

    NSMutableData *data = [NSMutableData dataWithLength:di_info->output_size];
    cchmac_final(di_info, hmac_ctx, (unsigned char*)data.mutableBytes);

    return data;
}

@interface RPVLoginImpl ()

@property (nonatomic, strong) NSDictionary *lookupURLs;

#if TARGET_OS_IOS
@property (nonatomic, readwrite) struct ccrng_state *rngState;
#endif

@end

@implementation RPVLoginImpl

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.clientInfoOverride = @"<iMac11,3> <Mac OS X;10.10.4;14E46> <http://com.apple.Xcode/217>";
        
#if TARGET_OS_IOS
        // Create rng pointer
        
        NSOperatingSystemVersion version;
        version.majorVersion = 10;
        version.minorVersion = 0;
        version.patchVersion = 0;
        
        if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version]) {
            self.rngState = ccrng(NULL);
        } else {
            self.rngState = (struct ccrng_state*)malloc(sizeof(struct ccrng_system_state));
            ccrng_system_init((struct ccrng_system_state*)self.rngState);
        }
#endif
        
    }
    
    return self;
}

- (void)dealloc {
#if TARGET_OS_IOS

    // Free rng pointer if needed
    NSOperatingSystemVersion version;
    version.majorVersion = 10;
    version.minorVersion = 0;
    version.patchVersion = 0;
    
    if (![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version]) {
        ccrng_system_done((struct ccrng_system_state*)self.rngState);
    }
    
#endif
}

-(NSError*)createError:(NSString *)string :(int)code {
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: NSLocalizedString(string, nil),
                               NSLocalizedFailureReasonErrorKey: NSLocalizedString(string, nil),
                               NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                               };
    
    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:code
                                     userInfo:userInfo];
    
    return error;
}

- (void)_ensureAuthKitAvailable {
    dlopen("/System/Library/PrivateFrameworks/AuthKit.framework/AuthKit", RTLD_NOW);
}

- (NSDictionary *)_anisetteData {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    NSString *dateString = [formatter stringFromDate:[NSDate date]];

    [self _ensureAuthKitAvailable];

    Class AKAppleIDSession = NSClassFromString(@"AKAppleIDSession");
    NSDictionary *headers = [[[AKAppleIDSession alloc] initWithIdentifier:@"com.apple.gs.xcode.auth"] appleIDHeadersForRequest:nil];
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    [result setObject:dateString forKey:@"X-Apple-I-Client-Time"];
    [result setObject:NSLocale.currentLocale.localeIdentifier forKey:@"X-Apple-Locale"];
    [result setObject:NSTimeZone.localTimeZone.abbreviation forKey:@"X-Apple-I-TimeZone"];
    
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [result setObject:value forKey:key];
    }];
    
    [result setObject:self.clientInfoOverride forKey:@"X-MMe-Client-Info"];

    return result;
}

- (NSDictionary *)_deviceData {
    // Note: X-Apple-I-PRK is also sent, however it's a password reset key which (I think) may not always
    // be present even in genuine requests. It requires another account on device. So let's not include
    // it for now.
    //
    // In fact, the only X-whatever key required here is the device X-Mme-Device-Id
    // (which I believe must match that of a provisioned device)

    [self _ensureAuthKitAvailable];
    
    AKDevice *device = [NSClassFromString(@"AKDevice") currentDevice];
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    if (device.uniqueDeviceIdentifier)
        [result setObject:device.uniqueDeviceIdentifier forKey:@"X-Mme-Device-Id"];
    
    if ([device respondsToSelector:@selector(MLBSerialNumber)] && device.MLBSerialNumber)
        [result setObject:device.MLBSerialNumber forKey:@"X-Apple-I-MLB"];
    
    if ([device respondsToSelector:@selector(ROMAddress)] && device.ROMAddress)
        [result setObject:device.ROMAddress forKey:@"X-Apple-I-ROM"];
    
    if (device.serialNumber)
        [result setObject:device.serialNumber forKey:@"X-Apple-I-SRL-NO"];
    
    return result;
}

- (NSDictionary*)defaultRequestHeaders {
    return @{
        @"X-MMe-Client-Info": self.clientInfoOverride,
        @"Content-Type": @"text/x-xml-plist",
        @"User-Agent": @"akd/1.0 CFNetwork/978.0.7 Darwin/18.7.0",
        @"Accept": @"*/*"
    };
}

- (void)makeRequestWithParameters:(NSDictionary*)params completion:(void (^)(NSError *err, NSDictionary *response))completionHandler {
    NSString *internalEndpoint = @"https://gsa.apple.com/grandslam/GsService2";
    
    NSDictionary *defaultHeaders = [self defaultRequestHeaders];

    NSDictionary *requestBody = @{
        @"Header": @{
            @"Version": @"1.0.1"
        },
        @"Request": params
    };

    log_debug("Request Body: %s", requestBody.description.UTF8String);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:internalEndpoint]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSPropertyListSerialization dataWithPropertyList:requestBody
                                                                  format:NSPropertyListXMLFormat_v1_0
                                                                 options:0
                                                                   error:nil];
    
    [defaultHeaders enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [request setValue:obj forHTTPHeaderField:key];
    }];
    
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error) {
            completionHandler(error, nil);
        } else if (!data) {
            completionHandler(nil, nil);
        } else {
            NSDictionary *response = [NSPropertyListSerialization propertyListWithData:data
                                                                               options:0
                                                                                format:nil
                                                                                 error:nil];
            NSDictionary *packedResponse = [response objectForKey:@"Response"];
            
            log_debug("Response: %s", packedResponse.description.UTF8String);
            
            completionHandler(nil, packedResponse);
        }
        
    }];
    [task resume];
}

- (void)initialiseLookup:(void (^)(NSError*))completion {
    if (self.lookupURLs) {
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(nil);
        });
        return;
    }
    
    NSURL *URL = [NSURL URLWithString:@"https://gsa.apple.com/grandslam/GsService2/lookup"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    log_debug("Doing lookup");
    
    // Sort out headers
    NSMutableDictionary<NSString *, NSString *> *httpHeaders = [@{
        @"Content-Type": @"text/x-xml-plist",
        @"User-Agent": @"akd/1.0 CFNetwork/978.0.7 Darwin/18.7.0",
        @"Accept": @"text/x-xml-plist",
        @"Accept-Language": @"en-us",
        @"X-Apple-App-Info": @"com.apple.gs.xcode.auth",
        @"X-Xcode-Version": @"11.2 (11B41)",
    } mutableCopy];
    
    [httpHeaders addEntriesFromDictionary:[self _anisetteData]];
    [httpHeaders addEntriesFromDictionary:[self _deviceData]];
    
    [httpHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
    
    log_debug("Request Headers: %s", httpHeaders.description.UTF8String);
    
    // Do the request
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        log_debug("Response code: %ld", (long)[(NSHTTPURLResponse*)response statusCode]);
        
        if (!data || error) {
            completion(error);
        } else {
            // Parse the response
            NSError *parseError;
            NSDictionary *responseDictionary = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:&parseError];
            
            if (responseDictionary) {
                log_debug("Reponse: %s", responseDictionary.description.UTF8String);
                
                self.lookupURLs = [responseDictionary objectForKey:@"urls"];
            }
            
            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completion(nil);
            });
        }
    }];
    [task resume];
}

#pragma mark API

- (void)loginWithUsername:(NSString*)username password:(NSString*)password completion:(RPVLoginResultBlock)completionHandler {
    
    // Ensure lookup URLs are populated first
    [self initialiseLookup:^(NSError *error) {
        if (error) {
            completionHandler(error, nil, nil, nil);
        } else {
    
            NSMutableDictionary *clientData = @{
                @"bootstrap": @YES,
                @"icscrec": @YES,
                @"loc": NSLocale.currentLocale.localeIdentifier,
                @"pbe": @NO,
                @"prkgen": @YES,
                @"svct": @"iCloud",
            }.mutableCopy;
            [clientData addEntriesFromDictionary:[self _anisetteData]];
            [clientData addEntriesFromDictionary:[self _deviceData]];

            ccsrp_const_gp_t gp = ccsrp_gp_rfc5054_2048();
            
            const struct ccdigest_info *di_info = ccsha256_di();
            struct ccdigest_ctx *di_ctx = (struct ccdigest_ctx *)malloc(ccdigest_di_size(di_info));
            ccdigest_init(di_info, di_ctx);
            
            // MARK: AppleIDAuthSupport`stateClientNeg1
            
            const struct ccdigest_info *srp_di = ccsha256_di();
            struct ccsrp_ctx_body *srp_ctx = (struct ccsrp_ctx_body *)malloc(ccsrp_sizeof_srp(di_info, gp));

#if TARGET_OS_IOS
            ccsrp_ctx_init(srp_ctx, srp_di, gp, self.rngState);
            srp_ctx->hdr.blinding_rng = self.rngState;
#else
            ccsrp_ctx_init(srp_ctx, srp_di, gp, ccrng(NULL));
            srp_ctx->hdr.blinding_rng = ccrng(NULL);
#endif
            
            srp_ctx->hdr.flags.noUsernameInX = true;

            NSArray<NSString *> *ps = @[@"s2k", @"s2k_fo"];
            for (int i = 0; i < ps.count; i++) {
                addStringToNegProt(di_info, di_ctx, ps[i].UTF8String);
                if (i != ps.count - 1) addStringToNegProt(di_info, di_ctx, ",");
            }

            size_t A_size = ccsrp_exchange_size(srp_ctx);
            char A_bytes[A_size];
            ccsrp_client_start_authentication(srp_ctx, ccDRBGGetRngState(), A_bytes);

            NSData *AData = [NSData dataWithBytes:A_bytes length:A_size];

            addStringToNegProt(di_info, di_ctx, "|");
            
            // Initial request to GSA
            
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            __block NSDictionary *initResponse = nil;
            [self makeRequestWithParameters:@{
                @"A2k": AData,
                @"ps": ps,
                @"cpd": clientData,
                @"u": username,
                @"o": @"init"
            } completion:^(NSError *err, NSDictionary *response) {
                if (response) {
                    initResponse = response;
                } else {
                    completionHandler(err, nil, nil, nil);
                }
                
                dispatch_semaphore_signal(semaphore);
            }];
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
            // Handle response
            if (!initResponse) {
                return;
            }
            
            NSDictionary *initialResponseStatus = [initResponse objectForKey:@"Status"];
            if ([initialResponseStatus objectForKey:@"ec"] &&
                [[initialResponseStatus objectForKey:@"ec"] intValue] != 0) {
                // Error during request
                NSError *responseError = [self createError:[initialResponseStatus objectForKey:@"em"]
                                                          :[[initialResponseStatus objectForKey:@"ec"] intValue]];
                completionHandler(responseError, nil, nil, nil);
                return;
            }

            // MARK: AppleIDAuthSupport`stateClientNeg2
            // Generate the password key with the salt and interations requested by GSA

            size_t M_len = ccsrp_get_session_key_length(srp_ctx);
            char M_buf[M_len];

            NSString *respSP = initResponse[@"sp"];
            BOOL isS2K = [respSP isEqualToString:@"s2k"];
            addStringToNegProt(di_info, di_ctx, "|");
            if (respSP) addStringToNegProt(di_info, di_ctx, respSP.UTF8String);

            NSString *respC = initResponse[@"c"];
            NSData *respSalt = initResponse[@"s"];
            NSNumber *respIterations = initResponse[@"i"];
            NSData *bData = initResponse[@"B"];

            NSData *passKey = PBKDF2SRP(di_info, !isS2K, password, respSalt, respIterations);
            if (!passKey) {
                log_error("Could not generate password key!");
                NSError *error = [self createError:@"Could not generate password key" :RPVInternalLoginError];
                completionHandler(error, nil, nil, nil);
                return;
            }

            int result = ccsrp_client_process_challenge(srp_ctx,
                                                        username.UTF8String,
                                                        passKey.length, passKey.bytes,
                                                        respSalt.length, respSalt.bytes,
                                                        bData.bytes,
                                                        M_buf);
            if (result != 0) {
                log_error("Could not process challenge!");
                NSError *error = [self createError:@"Could not process challenge" :RPVInternalLoginError];
                completionHandler(error, nil, nil, nil);
                return;
            }

            NSData *MData = [NSData dataWithBytes:M_buf length:M_len];
            
            
            // 'Complete' response to GSA
            semaphore = dispatch_semaphore_create(0);
            __block NSDictionary *completeResponse = nil;
            [self makeRequestWithParameters:@{
                @"c": respC,
                @"M1": MData,
                @"cpd": clientData,
                @"u": username,
                @"o": @"complete"
            } completion:^(NSError *err, NSDictionary *response) {
                if (response) {
                    completeResponse = response;
                } else {
                    completionHandler(err, nil, nil, nil);
                }
                
                dispatch_semaphore_signal(semaphore);
            }];
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
            // Handle 'complete' response
            if (!completeResponse) {
                return;
            }
            
            NSDictionary *completeResponseStatus = [completeResponse objectForKey:@"Status"];
            if ([completeResponseStatus objectForKey:@"ec"] &&
                [[completeResponseStatus objectForKey:@"ec"] intValue] != 0) {
                // Don't error out just yet if 2FA has been requested
                // We need the idms token for that to be handled correctly
                
                if ([completeResponseStatus objectForKey:@"au"]) {
                    // Ignore the error for now, because authentication is still required
                } else {
                    NSError *responseError = [self createError:[completeResponseStatus objectForKey:@"em"]
                                                              :[[completeResponseStatus objectForKey:@"ec"] intValue]];
                    completionHandler(responseError, nil, nil, nil);
                    return;
                }
            }

            // MARK: AppleIDAuthSupport`stateClientNeg3

            NSData *M2Data = completeResponse[@"M2"];
            if (!M2Data) {
                log_error("Missing M2 data!");
                NSError *error = [self createError:@"Missing M2 data" :RPVInternalLoginError];
                completionHandler(error, nil, nil, nil);
                return;
            }
            size_t data_len = M2Data.length;
            if (data_len != ccsrp_get_session_key_length(srp_ctx)) {
                log_error("Invalid M2 len!");
                NSError *error = [self createError:@"Invalid M2 len" :RPVInternalLoginError];
                completionHandler(error, nil, nil, nil);
                return;
            }

            if (!ccsrp_client_verify_session(srp_ctx, M2Data.bytes)) {
                log_error("Could not verify session!");
                NSError *error = [self createError:@"Could not verify session" :RPVInternalLoginError];
                completionHandler(error, nil, nil, nil);
                return;
            }

            addStringToNegProt(di_info, di_ctx, "|");

            NSData *spd = completeResponse[@"spd"];
            if (spd) {
                addDataToNegProt(di_info, di_ctx, spd);
            }
            addStringToNegProt(di_info, di_ctx, "|");

            NSData *sc = completeResponse[@"sc"];
            if (sc) {
                addDataToNegProt(di_info, di_ctx, sc);
            }
            addStringToNegProt(di_info, di_ctx, "|");

            NSData *negProto = completeResponse[@"np"];
            if (!negProto) {
                log_error("Neg proto missing!");
                NSError *error = [self createError:@"Neg proto missing" :RPVInternalLoginError];
                completionHandler(error, nil, nil, nil);
                return;
            }

            size_t digest_len = di_info->output_size;

            if (negProto.length != digest_len) {
                log_error("Neg proto hash too short");
                NSError *error = [self createError:@"Neg proto hash too short" :RPVInternalLoginError];
                completionHandler(error, nil, nil, nil);
                return;
            }

            unsigned char digest[digest_len];
            di_info->final(di_info, di_ctx, digest);

            unsigned char hmac_out[digest_len];
            NSData *hmacKey = createSessionKey(srp_ctx, "HMAC key:");
            cchmac(di_info,
                   hmacKey.length, hmacKey.bytes,
                   digest_len, digest,
                   hmac_out);

            if (cc_cmp_safe(digest_len, hmac_out, negProto.bytes)) {
                log_error("Invalid neg prot hmac!");
                NSError *error = [self createError:@"Invalid neg prot hmac" :RPVInternalLoginError];
                completionHandler(error, nil, nil, nil);
                return;
            }

            NSData *decrypted = decryptCBC(srp_ctx, spd);
            if (!decrypted) {
                log_error("Could not decrypt login response!");
                NSError *error = [self createError:@"Could not decrypt login response" :RPVInternalLoginError];
                completionHandler(error, nil, nil, nil);
                return;
            }
            NSDictionary *decryptedDict = [NSPropertyListSerialization propertyListWithData:decrypted options:0 format:nil error:nil];
            if (!decryptedDict) {
                log_error("Could not parse decrypted login response plist!");
                NSError *error = [self createError:@"Could not parse decrypted login response plist" :RPVInternalLoginError];
                completionHandler(error, nil, nil, nil);
                return;
            }

            // MARK: AppleIDAuthSupport`AppleIDAuthSupportCopyAppTokensOptions

            NSString *adsid = decryptedDict[@"adsid"];
            NSString *acname = decryptedDict[@"acname"];
            NSString *altDSID = [NSString stringWithFormat:@"%@|%@", adsid, acname];

            NSString *idmsToken = decryptedDict[@"GsIdmsToken"];
            
            log_debug("IDMS Token: %s", idmsToken.UTF8String);
            
            // At this point, check if 2FA is required. If so, return with the idms token and adsid
            if ([completeResponseStatus objectForKey:@"au"]) {
                
                int mode = [[completeResponseStatus objectForKey:@"au"] isEqualToString:@"trustedDeviceSecondaryAuth"] ?
                    RPVInternalLogin2FARequiredTrustedDeviceError :
                    RPVInternalLogin2FARequiredSecondaryAuthError;
                
                NSError *responseError = [self createError:[completeResponseStatus objectForKey:@"em"]
                                                          :mode];
                
                completionHandler(responseError, altDSID, nil, idmsToken);
            } else {
            
                NSData *completeSK = decryptedDict[@"sk"];
                NSData *completeC = decryptedDict[@"c"];
                
                NSString *app = @"com.apple.gs.xcode.auth";
                NSArray<NSString *> *apps = @[app];

                NSData *checksum = createAppTokensChecksum(completeSK, adsid, apps);
                
                // 'Tokens' response to GSA
                semaphore = dispatch_semaphore_create(0);
                __block NSDictionary *tokensResponse = nil;
                [self makeRequestWithParameters:@{
                    @"u": adsid,
                    @"app": apps,
                    @"c": completeC,
                    @"t": idmsToken,
                    @"checksum": checksum,
                    @"cpd": clientData,
                    @"o": @"apptokens"
                } completion:^(NSError *err, NSDictionary *response) {
                    if (response) {
                        tokensResponse = response;
                    } else {
                        completionHandler(err, nil, nil, nil);
                    }
                    
                    dispatch_semaphore_signal(semaphore);
                }];
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                
                // Handle 'complete' response
                if (!tokensResponse) {
                    return;
                }
                
                NSDictionary *tokensResponseStatus = [tokensResponse objectForKey:@"Status"];
                if ([tokensResponseStatus objectForKey:@"ec"] &&
                    [[tokensResponseStatus objectForKey:@"ec"] intValue] != 0) {
                    // Error during request
                    NSError *responseError = [self createError:[tokensResponseStatus objectForKey:@"em"]
                                                              :[[tokensResponseStatus objectForKey:@"ec"] intValue]];
                    
                    completionHandler(responseError, nil, nil, nil);
                    return;
                }

                NSData *encryptedToken = tokensResponse[@"et"];
                NSData *decryptedToken = decryptGCM(completeSK, encryptedToken);
                if (!decryptedToken) {
                    log_error("Could not decrypt apptoken!");
                    NSError *error = [self createError:@"Could not decrypt apptoken" :RPVInternalLoginError];
                    completionHandler(error, nil, nil, nil);
                    return;
                }
                NSDictionary *decryptedTokDict = [NSPropertyListSerialization propertyListWithData:decryptedToken options:0 format:nil error:nil];
                if (!decryptedTokDict) {
                    log_error("Could not parse decrypted apptoken plist!");
                    NSError *error = [self createError:@"Could not parse decrypted apptoken plist" : RPVInternalLoginError];
                    completionHandler(error, nil, nil, nil);
                    return;
                }
                log_debug("Decrypted token dict: %s", decryptedTokDict.description.UTF8String);

                NSDictionary *tokenDict = decryptedTokDict[@"t"][app];
                NSString *token = tokenDict[@"token"];
                
                completionHandler(nil, altDSID, token, nil);
            }
        }
    }];
}

- (void)_checkAuthEndpointWithUserIdentity:(NSString*)userIdentity idmsToken:(NSString*)token andCompletion:(void (^)(NSError *error, NSArray *deviceIds))completionHandler {
    
    NSString *dsid = [userIdentity componentsSeparatedByString:@"|"].firstObject;
    
    NSURL *URL = self.lookupURLs ?
        [NSURL URLWithString:[self.lookupURLs objectForKey:@"secondaryAuth"]] :
        [NSURL URLWithString:@"https://gsa.apple.com/auth"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    log_debug("Request to: %s", URL.description.UTF8String);
    
    NSString *identityToken = [NSString stringWithFormat:@"%@:%@", dsid, token];
    
    NSData *identityTokenData = [identityToken dataUsingEncoding:NSUTF8StringEncoding];
    NSString *encodedIdentityToken = [identityTokenData base64EncodedStringWithOptions:0];
    
    // Sort out headers
    NSMutableDictionary<NSString *, NSString *> *httpHeaders = [@{
        @"Content-Type": @"text/x-xml-plist",
        @"User-Agent": @"akd/1.0 CFNetwork/978.0.7 Darwin/18.7.0",
        @"Accept": @"text/x-xml-plist",
        @"Accept-Language": @"en-us",
        @"X-Apple-Client-App-Name": @"Xcode",
        @"X-Apple-App-Info": @"com.apple.gs.xcode.auth",
        @"X-Xcode-Version": @"11.2 (11B41)",
        @"X-Apple-Identity-Token": encodedIdentityToken,
    } mutableCopy];
    
    [httpHeaders addEntriesFromDictionary:[self _anisetteData]];
    [httpHeaders addEntriesFromDictionary:[self _deviceData]];
    
    [httpHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
    
    [request setValue:self.clientInfoOverride forHTTPHeaderField:@"X-MMe-Client-Info"];
    
    // Do the request
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        log_debug("Response code: %ld", (long)[(NSHTTPURLResponse*)response statusCode]);
        
        if (!data || error) {
            log_debug("NO DATA OR ERROR");
            completionHandler(error, @[]);
        } else {
            // Parse the response
            NSError *parseError;
            NSDictionary *responseDictionary = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:&parseError];
            
            if (responseDictionary) {
                log_debug("Reponse: %s", responseDictionary.description.UTF8String);
            }
            
            // TODO: Something with the response
            completionHandler(nil, @[]);
        }
    }];
    [task resume];
}

- (void)requestTwoFactorCodeWithUserIdentity:(NSString*)userIdentity idmsToken:(NSString*)token mode:(int)mode andCompletion:(void (^)(NSError *error))completionHandler {
    
    // Parse the real dsid out of the identity
    NSString *dsid = [userIdentity componentsSeparatedByString:@"|"].firstObject;
    
    // Change URL depending on the mode
    NSURL *URL = nil;
    if (mode == RPVInternalLogin2FARequiredTrustedDeviceError) {
        URL = self.lookupURLs ?
                [NSURL URLWithString:[self.lookupURLs objectForKey:@"trustedDeviceSecondaryAuth"]] :
                [NSURL URLWithString:@"https://gsa.apple.com/auth/verify/trusteddevice"];
    } else {
        URL = [NSURL URLWithString:@"https://gsa.apple.com/auth/verify/phone/put?mode=sms&referrer=/auth/verify/trusteddevice"];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    log_debug("Request to: %s", URL.description.UTF8String);
    
    NSString *identityToken = [NSString stringWithFormat:@"%@:%@", dsid, token];
    
    NSData *identityTokenData = [identityToken dataUsingEncoding:NSUTF8StringEncoding];
    NSString *encodedIdentityToken = [identityTokenData base64EncodedStringWithOptions:0];
    
    // Sort out headers
    NSMutableDictionary<NSString *, NSString *> *httpHeaders = [@{
        @"Content-Type": @"text/x-xml-plist",
        @"User-Agent": @"akd/1.0 CFNetwork/978.0.7 Darwin/18.7.0",
        @"Accept": @"text/x-xml-plist",
        @"Accept-Language": @"en-us",
        @"X-Apple-App-Info": @"com.apple.gs.xcode.auth",
        @"X-Apple-Client-App-Name": @"Xcode",
        @"X-Xcode-Version": @"11.2 (11B41)",
        @"X-Apple-Identity-Token": encodedIdentityToken,
    } mutableCopy];
    
    [httpHeaders addEntriesFromDictionary:[self _anisetteData]];
    [httpHeaders addEntriesFromDictionary:[self _deviceData]];
    
    [httpHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
    
    [request setValue:self.clientInfoOverride forHTTPHeaderField:@"X-MMe-Client-Info"];
    
    log_debug("Request Headers: %s", httpHeaders.description.UTF8String);
    
    // Match post data used by Preferences
    if (mode == RPVInternalLogin2FARequiredSecondaryAuthError) {
        // This really should be querying https://gsa.apple.com/auth/ for available numbers?
        NSDictionary *postData = @{
            @"serverInfo": @{
                @"phoneNumber.id": @"1"
            },
        };
        
        request.HTTPMethod = @"POST";
        request.HTTPBody = [NSPropertyListSerialization dataWithPropertyList:postData
                                                                      format:NSPropertyListXMLFormat_v1_0
                                                                     options:0
                                                                       error:nil];
        
        [self _checkAuthEndpointWithUserIdentity:userIdentity idmsToken:token andCompletion:^(NSError *error, NSArray *deviceIds) {
            
        }];
    }
    
    // Do the request
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        log_debug("Response code: %ld", (long)[(NSHTTPURLResponse*)response statusCode]);
        
        if (!data || error) {
            completionHandler(error);
        } else {
            // Parse the response
            NSError *parseError;
            NSDictionary *responseDictionary = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:&parseError];
            
            if (responseDictionary) {
                log_debug("Reponse: %s", responseDictionary.description.UTF8String);
            }
            
            completionHandler(nil);
        }
    }];
    [task resume];
}

- (void)submitTwoFactorCode:(NSString*)code withUserIdentity:(NSString*)userIdentity idmsToken:(NSString*)token andCompletion:(RPVTwoFactorResultBlock)completionHandler {
    
    // Parse the real dsid out of the identity
    NSString *dsid = [userIdentity componentsSeparatedByString:@"|"].firstObject;
    
    NSURL *URL = nil;
    if (self.lookupURLs) {
        URL = [NSURL URLWithString:[self.lookupURLs objectForKey:@"validateCode"]];
    } else {
        URL = [NSURL URLWithString:@"https://gsa.apple.com/grandslam/GsService2/validate"];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    log_debug("Request to: %s", URL.description.UTF8String);
    
    NSString *identityToken = [NSString stringWithFormat:@"%@:%@", dsid, token];
    
    NSData *identityTokenData = [identityToken dataUsingEncoding:NSUTF8StringEncoding];
    NSString *encodedIdentityToken = [identityTokenData base64EncodedStringWithOptions:0];
    
    // Sort out headers
    NSMutableDictionary<NSString *, NSString *> *httpHeaders = [@{
        @"security-code": code,
        @"Content-Type": @"text/x-xml-plist",
        @"User-Agent": @"akd/1.0 CFNetwork/978.0.7 Darwin/18.7.0",
        @"Accept": @"text/x-xml-plist",
        @"Accept-Language": @"en-us",
        @"X-Apple-App-Info": @"com.apple.gs.xcode.auth",
        @"X-Apple-Client-App-Name": @"Xcode",
        @"X-Xcode-Version": @"11.2 (11B41)",
        @"X-Apple-Identity-Token": encodedIdentityToken,
    } mutableCopy];
    
    [httpHeaders addEntriesFromDictionary:[self _anisetteData]];
    [httpHeaders addEntriesFromDictionary:[self _deviceData]];
    
    [httpHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
    
    [request setValue:self.clientInfoOverride forHTTPHeaderField:@"X-MMe-Client-Info"];
    
    log_debug("Request Headers: %s", httpHeaders.description.UTF8String);
    
    // Do the request
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (!data || error) {
            completionHandler(error);
        } else {
            
            // Parse the response
            NSError *parseError;
            NSDictionary *responseDictionary = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:&parseError];
            
            // Handle parse issues
            if (!responseDictionary) {
                NSError *error = [self createError:parseError.localizedDescription :RPVInternalLoginError];
                completionHandler(error);
                return;
            }
            
            log_debug("Request Reponse: %s", responseDictionary.description.UTF8String);
            
            NSInteger errorCode = [responseDictionary[@"ec"] integerValue]; // Same for NSString or NSNumber.
            if (errorCode == 0) {
                // Success! However, still need to re-login again
                completionHandler(nil);
            } else if (errorCode == -21669) {
                NSError *error = [self createError:@"Incorrect 2FA code" :RPVInternalLoginIncorrect2FACodeError];
                completionHandler(error);
            } else {
                NSError *responseError = [self createError:[responseDictionary objectForKey:@"em"]
                                                          :[[responseDictionary objectForKey:@"ec"] intValue]];
                
                completionHandler(responseError);
            }
        }
    }];
    [task resume];
}

@end
