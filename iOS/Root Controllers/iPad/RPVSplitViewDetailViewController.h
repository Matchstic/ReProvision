//
//  RPVSplitViewDetailViewController.h
//  iOS
//
//  Created by Matt Clarke on 04/06/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    kItemApplications,
    kItemTroubleshooting,
    kItemSettings
} RPVSplitViewSelectedItem;

@interface RPVSplitViewDetailViewController : UIViewController

- (void)setupController;
- (void)presentSelectedItem:(RPVSplitViewSelectedItem)item;

@end
