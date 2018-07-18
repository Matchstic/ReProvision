//
//  RPVRootViewController.m
//  iOS
//
//  Created by Matt Clarke on 04/06/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVRootViewController.h"
#import "RPVSplitViewDetailViewController.h"
#import "RPVSplitViewMasterTableViewController.h"

@interface RPVRootViewController ()

@end

@implementation RPVRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Conditionally configure the root controller.
    UIViewController *mainViewController;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        mainViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"SplitViewRoot"];
    } else {
        mainViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"TabBarRoot"];
    }
    
    [self addChildViewController:mainViewController];
    [self.view addSubview:mainViewController.view];
    
    [mainViewController didMoveToParentViewController:self];
    [mainViewController.view setFrame:self.view.bounds];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self _setupSplitController:(UISplitViewController *)mainViewController];
    }
    
    // Update status bar style.
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)_setupSplitController:(UISplitViewController*)splitController {
    // Setup master-detail link.
    
    splitController.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    
    RPVSplitViewMasterTableViewController *masterController = (RPVSplitViewMasterTableViewController*)[(UINavigationController*)[splitController.viewControllers firstObject] topViewController];
    
    RPVSplitViewDetailViewController *detailController = (RPVSplitViewDetailViewController*)splitController.viewControllers.lastObject;
    
    masterController.detailViewController = detailController;
    
    // Present applications controller
    [detailController presentSelectedItem:kItemApplications];
    [masterController.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    // Only ever have one child at any time.
    return self.childViewControllers.count > 0 ? [[self.childViewControllers objectAtIndex:0] preferredStatusBarStyle] : UIStatusBarStyleDefault;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
