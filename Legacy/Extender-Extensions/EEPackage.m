//
//  EEPackage.m
//  Extender Installer
//
//  Created by Matt Clarke on 14/04/2017.
//
//

#import "EEPackage.h"
#import "EEResources.h"
#import "SSZipArchive.h"
#import "EEPackageDatabase.h"

@interface Extender : UIApplication
- (void)sendLocalNotification:(NSString*)title andBody:(NSString*)body;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSURL *bundleURL;
- (id)localizedName;
+ (instancetype)applicationProxyForIdentifier:(NSString*)arg1;
- (id)primaryIconDataForVariant:(int)arg1;
@end

@implementation EEPackage

-(instancetype)initWithURL:(NSURL*)fileURL andBundleIdentifier:(NSString*)bundleIdentifier {
    self = [super init];
    
    if (self) {
        // Load Info.plist from the zip at this URL.
        _url = fileURL;
        
        _proxy = [LSApplicationProxy applicationProxyForIdentifier:bundleIdentifier];
    }
    
    return self;
}

- (NSString*)bundleIdentifier {
    return [_proxy applicationIdentifier];
}

- (NSString*)applicationName {
    return [_proxy localizedName];
}

- (UIImage*)applicationIcon {
    if (!_icon) {
        _icon = [UIImage imageWithData:[_proxy primaryIconDataForVariant:1]];
    }
    
    return _icon;
}

- (NSDate*)applicationExpireDate {
    // We find the application on-disk via MobileCoreServices, then read out it's provisioning profile.
    // Key is ExpirationDate
    
    LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:[self bundleIdentifier]];
    NSString *provisionPath = [[proxy.bundleURL path] stringByAppendingString:@"/embedded.mobileprovision"];
    
    NSDictionary *provision = [EEResources provisioningProfileAtPath:provisionPath];
    
    return [provision objectForKey:@"ExpirationDate"];
}

- (NSURL*)packageURL {
    return _url;
}

@end
