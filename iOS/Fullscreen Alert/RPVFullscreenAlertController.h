//
//  RPVFullscreenAlertController.h
//  iOS
//
//  Created by Matt Clarke on 16/01/2020.
//  Copyright © 2020 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RPVFullscreenAlertController : UIViewController

@property (nonatomic, copy) void (^onDismiss)();

@end
