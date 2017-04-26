//
//  PZFileBrowser.h
//  PartialZip
//
//  Created by Allan Kerr on 2015-06-29.
//
//

#import <Foundation/Foundation.h>

@interface PZFileBrowser : NSObject
+ (id)browserWithPath:(NSString *)path;
+ (id)browserWithPath:(NSString *)path byteRange:(NSRange)byteRange;
- (NSRange)getByteRangeFromPath:(NSString *)fromPath toPath:(NSString *)toPath;
- (NSData *)getDataForPath:(NSString *)path;
- (NSArray *)getAllPaths;
@end
