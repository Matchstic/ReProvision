//
//  RPVIpaBundleApplication.h
//  iOS
//
//  Created by Matt Clarke on 21/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVApplication.h"
#import "SSZipArchive.h"

@interface RPVIpaBundleApplication : RPVApplication <SSZipArchiveDelegate>

- (instancetype)initWithIpaURL:(NSURL*)url;

@end
