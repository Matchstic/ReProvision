//
//  RPVApplication.h
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class LSApplicationProxy;

@interface RPVApplication : NSObject

+ (NSDictionary *)provisioningProfileAtPath:(NSString *)path;

// Don't call this yourself.
- (instancetype)initWithApplicationProxy:(LSApplicationProxy*)proxy;

- (NSString*)bundleIdentifier;
- (NSString*)applicationName;
- (NSString*)applicationVersion;
- (NSNumber*)applicationInstalledSize;

// Make sure to call these two asynchronously
- (UIImage*)applicationIcon;
- (UIImage*)tvOSApplicationIcon;

- (NSDate*)applicationExpiryDate;
- (BOOL)hasEmbeddedMobileprovision;

- (NSURL*)locationOfApplicationOnFilesystem;

@end
