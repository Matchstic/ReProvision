//
//  RPVIpaBundleApplication.m
//  iOS
//
//  Created by Matt Clarke on 21/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVIpaBundleApplication.h"

#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

@interface RPVIpaBundleApplication ()

@property (nonatomic, strong) NSDictionary *cachedInfoPlist;
@property (nonatomic, strong) NSURL *cachedURL;
@property (nonatomic, strong) UIImage *cachedIconImage;
@property (nonatomic, strong) NSNumber *uncompressedSize;

@property (nonatomic, strong) NSString *_tmp_zipFileRequested;
@property (nonatomic, readwrite) BOOL _tmp_zipUncompressedSizeRequested;
@property (nonatomic, readwrite) int _tmp_zipUncompressedSize;

@end

@implementation RPVIpaBundleApplication

- (instancetype)initWithIpaURL:(NSURL*)url {
    self = [super init];
    
    if (self) {
        // Initialise by pre-loading information from the .ipa file.
        self.cachedInfoPlist = [self _loadInfoPlistFromURL:url];
        self.cachedIconImage = [self _loadApplicationIconFromURL:url withInfoPlist:self.cachedInfoPlist];
        self.uncompressedSize = [self _loadUncompressedFileSizeFromURL:url];
        
        self.cachedURL = url;
    }
    
    return self;
}

- (NSNumber*)_loadUncompressedFileSizeFromURL:(NSURL*)url {
    self._tmp_zipUncompressedSizeRequested = YES;
    self._tmp_zipUncompressedSize = 0;
    BOOL success = [SSZipArchive unzipFileAtPath:[url path] toDestination:NSTemporaryDirectory() delegate:self];
    self._tmp_zipUncompressedSizeRequested = NO;
    
    if (success) {
        return [NSNumber numberWithInt:self._tmp_zipUncompressedSize];
    } else {
        return @0;
    }
}

- (NSDictionary*)_loadInfoPlistFromURL:(NSURL*)url {
    NSData *data = [self _loadFileWithFormat:@"Payload/*/Info.plist" fromIPA:url multipleCandiateChooser:^NSString *(NSArray *candidates) {
        return [candidates firstObject];
    }];
    
    return [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
}

- (UIImage*)_loadApplicationIconFromURL:(NSURL*)url withInfoPlist:(NSDictionary*)infoPlist {
    // Check if this Info.plist has any icons.
    if (![infoPlist.allKeys containsObject:@"CFBundleIcons"] && ![infoPlist.allKeys containsObject:@"CFBundleIcons~ipad"]) {
        return [UIImage _applicationIconImageForBundleIdentifier:nil format:2 scale:[UIScreen mainScreen].scale];
    } else {
        NSDictionary *icons;
        BOOL usingIpadIcons = NO;
        if (!IS_IPAD)
            icons = [infoPlist objectForKey:@"CFBundleIcons"];
        else {
            // Prefer iPad icons, but fallback to iPhone if needed.
            if ([infoPlist.allKeys containsObject:@"CFBundleIcons~ipad"]) {
                icons = [infoPlist objectForKey:@"CFBundleIcons~ipad"];
                usingIpadIcons = YES;
            } else
                icons = [infoPlist objectForKey:@"CFBundleIcons"];
        }
        
        NSString *iconFileName = [[[icons objectForKey:@"CFBundlePrimaryIcon"] objectForKey:@"CFBundleIconFiles"] lastObject];
        
        // Add suffix as needed.
        
        // Now load this from the .ipa file
        NSString *fileFormat = [NSString stringWithFormat:@"Payload/*/%@", iconFileName];
        
        NSData *data = [self _loadFileWithFormat:fileFormat fromIPA:url multipleCandiateChooser:^NSString *(NSArray *candidates) {
            
            NSArray *suffixPreferences = @[@"@3x", @"@2x", @""];
            
            // Choose which candidate is best for the current device, and fallback as needed.
            NSString *currentBest = @"";
            int currentBestRank = 2;
            
            BOOL anyHaveIpadSuffix = NO;
            for (NSString *item in candidates) {
                if ([item containsString:@"~ipad"]) {
                    anyHaveIpadSuffix = YES;
                    break;
                }
            }
            
            for (NSString *item in candidates) {
                if (IS_IPAD && anyHaveIpadSuffix && ![item containsString:@"~ipad"])
                    continue;
        
                // Alright, maybe this one.
                
                // Base case
                if ([currentBest isEqualToString:@""]) {
                    currentBest = item;
                    currentBestRank = [self _rankItem:item forSuffixes:suffixPreferences];
                }
                
                // Go through the suffix preferences, and rank the currentBest and the new item.
                int itemRank = [self _rankItem:item forSuffixes:suffixPreferences];
                
                if (itemRank < currentBestRank) {
                    currentBest = item;
                    currentBestRank = itemRank;
                }
            }
        
            return currentBest;
        }];
        
        if (data)
            return [self _maskApplicationIcon:[UIImage imageWithData:data]];
        else
            return [UIImage _applicationIconImageForBundleIdentifier:nil format:2 scale:[UIScreen mainScreen].scale];
    }
}

- (int)_rankItem:(NSString*)item forSuffixes:(NSArray*)suffixes {
    int rank = (int)suffixes.count - 1;
    
    for (int i = 0; i < suffixes.count; i++) {
        NSString *suffix = [suffixes objectAtIndex:i];
        
        if ([item containsString:suffix]) {
            rank = i;
            break;
        }
    }
    
    return rank;
}

- (UIImage*)_maskApplicationIcon:(UIImage*)icon {
    UIImage *maskImage;
    @try {
       maskImage = [[UIImage _applicationIconImageForBundleIdentifier:@"" format:2 scale:[UIScreen mainScreen].scale] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } @catch (NSException *e) {
        // Really?! This is usually caused by AnemoneIcons.dylib
    }
    
    // See: https://stackoverflow.com/a/8127762
    CGImageRef maskRef = maskImage.CGImage;
    
    #define ROUND_UP(N, S) ((((N) + (S) - 1) / (S)) * (S))
    
    float width = CGImageGetWidth(maskRef);
    float height = CGImageGetHeight(maskRef);
    
    // Make a bitmap context that's only 1 alpha channel
    // WARNING: the bytes per row probably needs to be a multiple of 4
    int strideLength = ROUND_UP(width * 1, 4);
    unsigned char * alphaData = calloc(strideLength * height, sizeof(unsigned char));
    CGContextRef alphaOnlyContext = CGBitmapContextCreate(alphaData,
                                                          width,
                                                          height,
                                                          8,
                                                          strideLength,
                                                          NULL,
                                                          kCGImageAlphaOnly);
    
    // Draw the RGBA image into the alpha-only context.
    CGContextDrawImage(alphaOnlyContext, CGRectMake(0, 0, width, height), maskRef);
    
    // Walk the pixels and invert the alpha value. This lets you colorize the opaque shapes in the original image.
    // If you want to do a traditional mask (where the opaque values block) just get rid of these loops.
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            unsigned char val = alphaData[y*strideLength + x];
            val = 255 - val;
            alphaData[y*strideLength + x] = val;
        }
    }
    
    CGImageRef alphaMaskImage = CGBitmapContextCreateImage(alphaOnlyContext);
    CGContextRelease(alphaOnlyContext);
    free(alphaData);
    
    // Make a mask
    CGImageRef finalMaskImage = CGImageMaskCreate(CGImageGetWidth(alphaMaskImage),
                                                  CGImageGetHeight(alphaMaskImage),
                                                  CGImageGetBitsPerComponent(alphaMaskImage),
                                                  CGImageGetBitsPerPixel(alphaMaskImage),
                                                  CGImageGetBytesPerRow(alphaMaskImage),
                                                  CGImageGetDataProvider(alphaMaskImage), NULL, false);
    CGImageRelease(alphaMaskImage);
    
    CGImageRef masked = CGImageCreateWithMask([icon CGImage], finalMaskImage);
    
    CGImageRelease(finalMaskImage);
    
    return [UIImage imageWithCGImage:masked];
}

- (NSData*)_loadFileWithFormat:(NSString*)fileFormat fromIPA:(NSURL*)url multipleCandiateChooser:(NSString * (^)(NSArray *candidates))candidateChooser {
    NSString *destinationPath = NSTemporaryDirectory();
    if (!destinationPath)
        destinationPath = @"/tmp";
    
    NSString *uniquePath = [[NSUUID UUID] UUIDString];
    
    destinationPath = [destinationPath stringByAppendingString:uniquePath];
    
    // Load this file only from the zip.
    self._tmp_zipFileRequested = fileFormat;
    BOOL success = [SSZipArchive unzipFileAtPath:[url path] toDestination:destinationPath delegate:self];
    self._tmp_zipFileRequested = nil;
    
    if (success) {
        // Extracted the Info.plist file.
        for (NSString *pathComponent in [fileFormat pathComponents]) {
            if ([pathComponent isEqualToString:@"*"]) {
                // Expand the wildcard directory out.
                NSString *wildcardDirectory = nil;
                NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:destinationPath error:nil];
                for (NSString *file in contents) {
                    if (![file isEqualToString:@".DS_Store"]) {
                        wildcardDirectory = file;
                        break;
                    }
                }
                
                destinationPath = [destinationPath stringByAppendingFormat:@"/%@", wildcardDirectory];
            } else {
                destinationPath = [destinationPath stringByAppendingFormat:@"/%@", pathComponent];
            }
        }
        
        // We now have a fully qualified path. However, we also allow the usage of prefixes as the final path component.
        // In that situation, return the last file.
        
        NSArray *destinationContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[destinationPath stringByDeletingLastPathComponent] error:nil];
        
        if (destinationContents.count > 1) {
            destinationPath = [NSString stringWithFormat:@"%@/%@", [destinationPath stringByDeletingLastPathComponent], candidateChooser(destinationContents)];
        } else {
            destinationPath = [NSString stringWithFormat:@"%@/%@", [destinationPath stringByDeletingLastPathComponent], [destinationContents lastObject]];
        }
        
        NSData *data = [NSData dataWithContentsOfFile:destinationPath];
        
        // Delete directory structure from disk.
        NSString *tempDir = NSTemporaryDirectory();
        if (!tempDir)
            tempDir = @"/tmp";
        
        destinationPath = [tempDir stringByAppendingFormat:@"/%@", uniquePath];
        [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];
        
        return data;
    } else {
        return [NSData data];
    }
}

- (NSString*)bundleIdentifier {
    return [self.cachedInfoPlist objectForKey:@"CFBundleIdentifier"];
}
- (NSString*)applicationName {
    return [self.cachedInfoPlist objectForKey:@"CFBundleName"];
}

- (NSString*)applicationVersion {
    return [self.cachedInfoPlist objectForKey:@"CFBundleShortVersionString"];
}
- (NSNumber*)applicationInstalledSize {
    return self.uncompressedSize;
}

- (UIImage*)applicationIcon {
    return self.cachedIconImage;
}

- (NSDate*)applicationExpiryDate {
    return [NSDate date];
}

- (NSURL*)locationOfApplicationOnFilesystem {
    return self.cachedURL;
}

// SSZipArchive delegate
- (BOOL)zipArchiveShouldUnzipFileWithName:(NSString *)name fileInfo:(unz_file_info)fileInfo {
    // Update uncompressedSize if needed.
    if (self._tmp_zipUncompressedSizeRequested) {
        self._tmp_zipUncompressedSize += fileInfo.uncompressed_size;
        
        return NO;
    }
    
    int tmpPathComponentCount = (int)[self._tmp_zipFileRequested pathComponents].count;
    int givenCount = (int)[name pathComponents].count;
    
    if (tmpPathComponentCount != givenCount) {
        return NO;
    }
    
    if ([[name lastPathComponent] isEqualToString:[self._tmp_zipFileRequested lastPathComponent]] ||
        [[name lastPathComponent] hasPrefix:[self._tmp_zipFileRequested lastPathComponent]])
        return YES;
    
    return NO;
}

@end
