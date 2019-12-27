//
//  ShareViewController.m
//  iOS Share Extension
//
//  Created by Matt Clarke on 24/12/2019.
//  Copyright © 2019 Matt Clarke. All rights reserved.
//

#import "ShareViewController.h"

@interface ShareViewController ()

@end

@implementation ShareViewController

- (BOOL)openURL:(NSURL*)url {
    UIResponder *responder = self;
    UIApplication *application = nil;
    
    while (![[responder class] isEqual:[UIApplication class]] && responder != nil) {
        responder = responder.nextResponder;
        
        if ([[responder class] isEqual:[UIApplication class]]) {
            application = (UIApplication*)responder;
            break;
        }
    }
    
    if (application) {
        return (BOOL)[application performSelector:@selector(openURL:) withObject:url];
    } else {
        return NO;
    }
}

- (NSString *)getUUID {
    CFUUIDRef newUniqueId = CFUUIDCreate(kCFAllocatorDefault);
    NSString * uuidString = (__bridge_transfer NSString*)CFUUIDCreateString(kCFAllocatorDefault, newUniqueId);
    CFRelease(newUniqueId);

    return uuidString;
}

- (void)copyIncomingFileToInboxWithCompletion:(void (^)(BOOL success, NSURL *location))completion {
    NSExtensionItem *firstItem = [self.extensionContext.inputItems firstObject];
    NSItemProvider *firstAttachment = [firstItem.attachments firstObject];
    
    if ([firstAttachment hasItemConformingToTypeIdentifier:@"com.matchstic.reprovision.ipa"]) {
        [firstAttachment loadItemForTypeIdentifier:@"com.matchstic.reprovision.ipa"
                                           options:nil
                                 completionHandler:^(NSURL*  _Nullable item, NSError * _Null_unspecified error) {
            
            if (error) {
                NSLog(@"ReProvision :: %@", error);
            } else if (!item) {
                NSLog(@"ReProvision :: item is nil");
            }
            
            NSURL *downloadedFileURL = (NSURL*)item;
            
            completion(YES, downloadedFileURL);
        }];
    } else {
        completion(NO, nil);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Handle going to main app
    [self copyIncomingFileToInboxWithCompletion:^(BOOL success, NSURL *location) {
        if (success) {
            [self.extensionContext completeRequestReturningItems:@[] completionHandler:^(BOOL expired) {
                NSLog(@"Exited, launching main app");
                
                NSMutableCharacterSet *chars = NSCharacterSet.URLQueryAllowedCharacterSet.mutableCopy;
                [chars removeCharactersInRange:NSMakeRange('&', 1)];
                [chars removeCharactersInRange:NSMakeRange('/', 1)];
                
                NSString *encodedString = [[location path] stringByAddingPercentEncodingWithAllowedCharacters:chars];
                
                NSString *queryString = [NSString stringWithFormat:@"reprovision://share/%@", encodedString];
                
                [self openURL:[NSURL URLWithString:queryString]];
            }];
        } else {
            NSLog(@"FAILED TO COPY TO MAIN APP!");
        }
    }];
}

@end
