//
//  PZFileBrowser.m
//  PartialZip
//
//  Created by Allan Kerr on 2015-06-29.
//
//

#import "PZFileBrowser.h"
#include <zlib.h>

typedef struct CDEnd {
    uint32_t signature;
    uint16_t diskNo;
    uint16_t CDDiskNo;
    uint16_t CDDiskEntries;
    uint16_t CDEntries;
    uint32_t CDSize;
    uint32_t CDOffset;
    uint16_t lenComment;
} __attribute__ ((packed)) CDEnd;

typedef struct CDFile {
    uint32_t signature;
    uint16_t version;
    uint16_t versionExtract;
    uint16_t flags;
    uint16_t method;
    uint16_t modTime;
    uint16_t modDate;
    uint32_t crc32;
    uint32_t compressedSize;
    uint32_t size;
    uint16_t lenFileName;
    uint16_t lenExtra;
    uint16_t lenComment;
    uint16_t diskStart;
    uint16_t internalAttr;
    uint32_t externalAttr;
    uint32_t offset;
} __attribute__ ((packed)) CDFile;

typedef struct LocalFile {
    uint32_t signature;
    uint16_t versionExtract;
    uint16_t flags;
    uint16_t method;
    uint16_t modTime;
    uint16_t modDate;
    uint32_t crc32;
    uint32_t compressedSize;
    uint32_t size;
    uint16_t lenFileName;
    uint16_t lenExtra;
} __attribute__ ((packed)) LocalFile;

@interface PZFileBrowser ()
@property (nonatomic) uint16_t fileCount;
@property (nonatomic, retain) NSURL *url;
@property (nonatomic, retain) NSData *centralDirectory;
@end

@implementation PZFileBrowser

+ (id)browserWithPath:(NSString *)path
{
    return [[[self alloc] initWithPath:path] autorelease];
}

+ (id)browserWithPath:(NSString *)path byteRange:(NSRange)byteRange
{
    return [[[self alloc] initWithPath:path byteRange:byteRange] autorelease];
}

- (id)initWithPath:(NSString *)path
{
    if (self = [super init]) {
        self.url = [NSURL URLWithString:path];
        CDEnd *endOfCentralDirectory = [self findEndOfCentralDirectory];
        if(endOfCentralDirectory != NULL) {
            uint64_t start = endOfCentralDirectory->CDOffset;
            uint64_t end = start + endOfCentralDirectory->CDSize - 1;
            
            self.centralDirectory = [self getDataForFromByte:start toByte:end];
            self.fileCount = endOfCentralDirectory->CDEntries;
            free(endOfCentralDirectory);
        } else {
            [self release];
            return nil;
        }
    }
    return self;
}

- (id)initWithPath:(NSString *)path byteRange:(NSRange)byteRange
{
    if (self = [super init]) {
        self.url = [NSURL URLWithString:path];
        CDEnd *endOfCentralDirectory = [self findEndOfCentralDirectory];
        if(endOfCentralDirectory != NULL) {
            uint64_t start = MAX(endOfCentralDirectory->CDOffset, endOfCentralDirectory->CDOffset + byteRange.location);
            uint64_t end = MIN(start + endOfCentralDirectory->CDSize - 1, endOfCentralDirectory->CDOffset + NSMaxRange(byteRange));
            
            self.centralDirectory = [self getDataForFromByte:start toByte:end];
            self.fileCount = endOfCentralDirectory->CDEntries;
            free(endOfCentralDirectory);
        } else {
            [self release];
            return nil;
        }
    }
    return self;
}

- (CDEnd *)findEndOfCentralDirectory
{
    NSMutableURLRequest *headRequest = [NSMutableURLRequest requestWithURL:self.url];
    headRequest.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [headRequest setHTTPMethod:@"HEAD"];
    
    NSURLResponse *response;
    [NSURLConnection sendSynchronousRequest:headRequest returningResponse:&response error:nil];
    double dataLength = [response expectedContentLength];
    
    uint64_t start;
    if(dataLength > (0xffff + sizeof(CDEnd)))
        start = dataLength - 0xffff - sizeof(CDEnd);
    else {
        start = 0;
    }
    uint64_t end = dataLength - 1;
    
    NSData *directoryEnd = [self getDataForFromByte:start toByte:end];
    
    NSInteger offset = directoryEnd.length - sizeof(CDEnd);
    BOOL hasFoundEnd = false;
    CDEnd *endOfCentralDirectory = malloc(sizeof(CDEnd));
    while (hasFoundEnd == false && offset >= 0) {
        [directoryEnd getBytes:endOfCentralDirectory range:NSMakeRange(offset, sizeof(CDEnd))];
        hasFoundEnd = endOfCentralDirectory->signature == 0x06054b50 && offset + sizeof(CDEnd) + endOfCentralDirectory->lenComment ==  (unsigned long)directoryEnd.length;
        offset--;
    }
    if (!hasFoundEnd) {
        free(endOfCentralDirectory);
        endOfCentralDirectory = NULL;
    }
    return endOfCentralDirectory;
}

- (NSData *)getDataForFromByte:(uint64_t)start toByte:(uint64_t)end
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    
    NSString *range = [NSString stringWithFormat:@"bytes=%llu-%llu", start, end];
    [request setValue:range forHTTPHeaderField:@"Range"];
    [request setHTTPMethod: @"GET"];
    
    return [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
}

- (NSData *)getDataForPath:(NSString *)path
{
    const char *pathBytes = path.UTF8String;
    
    NSInteger offset = 0;
    int hasFoundPath = -1;
    CDFile *fileHeader = malloc(sizeof(CDFile));
    while (hasFoundPath != 0 && offset + sizeof(CDFile) < self.centralDirectory.length) {
        [self.centralDirectory getBytes:fileHeader range:NSMakeRange(offset, sizeof(CDFile))];

        NSInteger length = sizeof(CDFile) + fileHeader->lenFileName + fileHeader->lenExtra + fileHeader->lenComment;
        if (offset + length < self.centralDirectory.length) {
            char *fileName = malloc(fileHeader->lenFileName + 1);
            [self.centralDirectory getBytes:fileName range:NSMakeRange(offset + sizeof(CDFile), fileHeader->lenFileName)];
            fileName[fileHeader->lenFileName] = '\0';
            hasFoundPath = strcmp(pathBytes, fileName);
            free(fileName);
        }
        offset += sizeof(CDFile) + fileHeader->lenFileName + fileHeader->lenExtra + fileHeader->lenComment;
    }
    NSData *data;
    if (hasFoundPath == 0) {
        uint64_t start = fileHeader->offset;
        uint64_t end = fileHeader->offset + sizeof(LocalFile) - 1;
        
        LocalFile *localHeader = malloc(sizeof(LocalFile));
        NSData *localHeaderData = [self getDataForFromByte:start toByte:end];
        [localHeaderData getBytes:localHeader length:sizeof(LocalFile)];

        start = fileHeader->offset + sizeof(LocalFile) + localHeader->lenFileName + localHeader->lenExtra;
        end = start + fileHeader->compressedSize - 1;
    
        if (fileHeader->method == 8) {
            void *uncompressedData = malloc(fileHeader->size);
            z_stream stream;
            stream.zalloc = Z_NULL;
            stream.zfree = Z_NULL;
            stream.opaque = Z_NULL;
            stream.avail_in = 0;
            stream.next_in = NULL;
            
            inflateInit2(&stream, -MAX_WBITS);
            stream.avail_in = fileHeader->compressedSize;
            stream.next_in = (Bytef *)[self getDataForFromByte:start toByte:end].bytes;
            stream.avail_out = fileHeader->size;
            stream.next_out = uncompressedData;
            inflate(&stream, Z_FINISH);
            inflateEnd(&stream);
            data = [NSData dataWithBytes:uncompressedData length:fileHeader->size];
            free(uncompressedData);
        } else {
            data = [self getDataForFromByte:start toByte:end];
        }
        free(localHeader);
    } else {
        data = nil;
    }
    free(fileHeader);
    return data;
}

- (NSArray *)getAllPaths
{
    NSInteger offset = 0;
    NSMutableArray *allPaths = [NSMutableArray arrayWithCapacity:self.fileCount];
    CDFile *fileHeader = malloc(sizeof(CDFile));
    while (offset + sizeof(CDFile) < self.centralDirectory.length) {
        [self.centralDirectory getBytes:fileHeader range:NSMakeRange(offset, sizeof(CDFile))];

        NSInteger length = sizeof(CDFile) + fileHeader->lenFileName + fileHeader->lenExtra + fileHeader->lenComment;
        if (offset + length < self.centralDirectory.length) {
            char *fileName = malloc(fileHeader->lenFileName + 1);
            [self.centralDirectory getBytes:fileName range:NSMakeRange(offset + sizeof(CDFile), fileHeader->lenFileName)];
            fileName[fileHeader->lenFileName] = '\0';
            
            NSString *path = [NSString stringWithUTF8String:fileName];
            [allPaths addObject:path];
            free(fileName);
        }
        offset += length;
    }
    free(fileHeader);
    return [[allPaths copy] autorelease];
}

- (NSRange)getByteRangeFromPath:(NSString *)fromPath toPath:(NSString *)toPath
{
    const char *fromPathBytes = fromPath.UTF8String;
    const char *toPathBytes = toPath.UTF8String;
    
    NSInteger offset = 0, count = 0;
    uint64_t start = self.centralDirectory.length, end = 0;
    CDFile *fileHeader = malloc(sizeof(CDFile));
    while (count < 2 && offset + sizeof(CDFile) < self.centralDirectory.length) {
        [self.centralDirectory getBytes:fileHeader range:NSMakeRange(offset, sizeof(CDFile))];

        NSInteger length = sizeof(CDFile) + fileHeader->lenFileName + fileHeader->lenExtra + fileHeader->lenComment;
        if (offset + length < self.centralDirectory.length) {
            char *fileName = malloc(fileHeader->lenFileName + 1);
            [self.centralDirectory getBytes:fileName range:NSMakeRange(offset + sizeof(CDFile), fileHeader->lenFileName)];
            fileName[fileHeader->lenFileName] = '\0';
            
            if (strcmp(fromPathBytes, fileName) == 0 || strcmp(toPathBytes, fileName) == 0) {
                start = MIN(start, offset);
                end = MAX(end, offset + length);
                count++;
            }
            free(fileName);
        }
        offset += length;
    }
    NSRange range;
    if (start < self.centralDirectory.length && end > 0) {
        range = NSMakeRange(start, end - start);
    } else {
        range = NSMakeRange(NSNotFound, 0);
    }
    free(fileHeader);
    return range;
}

- (void)dealloc
{
    [_url release];
    [_centralDirectory release];
    [super dealloc];
}

@end
