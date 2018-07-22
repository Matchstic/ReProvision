//
//  AppDelegate.h
//  ReProvision
//
//  Created by Matt Clarke on 08/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RPVApplicationSigning.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, RPVApplicationSigningProtocol>

@property (strong, nonatomic) UIWindow *window;


@end

