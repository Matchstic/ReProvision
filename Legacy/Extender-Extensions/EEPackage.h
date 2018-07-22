//
//  EEPackage.h
//  Extender Installer
//
//  Created by Matt Clarke on 14/04/2017.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class LSApplicationProxy;

@interface EEPackage : NSObject {
    NSURL *_url;
    UIImage *_icon;
    NSDate *_installDate;
    LSApplicationProxy *_proxy;
}

-(instancetype)initWithURL:(NSURL*)fileURL andBundleIdentifier:(NSString*)bundleIdentifier;

- (NSString*)bundleIdentifier;
- (NSString*)applicationName;
- (UIImage*)applicationIcon;
- (NSDate*)applicationExpireDate;

- (NSURL*)packageURL;

@end
