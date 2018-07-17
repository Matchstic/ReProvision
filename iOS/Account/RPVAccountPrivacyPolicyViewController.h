//
//  RPVAccountPrivacyPolicyViewController.h
//  iOS
//
//  Created by Matt Clarke on 07/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface RPVAccountPrivacyPolicyViewController : UIViewController <WKNavigationDelegate>

@property (strong, nonatomic) WKWebView *webView;

@end
