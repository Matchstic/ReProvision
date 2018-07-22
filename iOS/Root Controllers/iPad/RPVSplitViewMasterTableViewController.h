//
//  RPVSplitViewMasterTableViewController.h
//  iOS
//
//  Created by Matt Clarke on 04/06/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RPVSplitViewDetailViewController.h"

@interface RPVSplitViewMasterTableViewController : UITableViewController

@property (nonatomic, weak) RPVSplitViewDetailViewController *detailViewController;

@end
