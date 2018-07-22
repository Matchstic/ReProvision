//
//  RPVWebViewController.h
//  iOS
//
//  Created by Matt Clarke on 15/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface RPVWebViewController : UIViewController <WKNavigationDelegate>

- (instancetype)initWithDocument:(NSString*)document;

@end
