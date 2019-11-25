//
//  RPVSplitViewDetailViewController.m
//  iOS
//
//  Created by Matt Clarke on 04/06/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVSplitViewDetailViewController.h"

@interface RPVSplitViewDetailViewController ()
@property (nonatomic, strong) UIViewController *installedController;
@property (nonatomic, strong) UIViewController *settingsController;
@property (nonatomic, strong) UIViewController *troubleshootingController;
@end

@implementation RPVSplitViewDetailViewController

- (void)setupController {
    // Load the controllers.
    self.installedController = [self.storyboard instantiateViewControllerWithIdentifier:@"InstalledController"];
    self.settingsController = [self.storyboard instantiateViewControllerWithIdentifier:@"SettingsController"];
    self.troubleshootingController = [self.storyboard instantiateViewControllerWithIdentifier:@"TroubleshootingController"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)presentSelectedItem:(RPVSplitViewSelectedItem)item {
    switch (item) {
        case kItemApplications:
            // Switch to the installed controller
            [self.settingsController removeFromParentViewController];
            [self.settingsController.view removeFromSuperview];
            [self.troubleshootingController removeFromParentViewController];
            [self.troubleshootingController.view removeFromSuperview];
            
            [self addChildViewController:self.installedController];
            [self.view addSubview:self.installedController.view];
            
            [self.installedController didMoveToParentViewController:self];
            [self.installedController.view setFrame:self.view.bounds];
            
            break;
        case kItemTroubleshooting:
            // Switch to troubleshooting controller
            [self.installedController removeFromParentViewController];
            [self.installedController.view removeFromSuperview];
            [self.settingsController removeFromParentViewController];
            [self.settingsController.view removeFromSuperview];
            
            [self addChildViewController:self.troubleshootingController];
            [self.view addSubview:self.troubleshootingController.view];
            
            [self.troubleshootingController didMoveToParentViewController:self];
            [self.troubleshootingController.view setFrame:self.view.bounds];
            
            break;
        case kItemSettings:
            // Switch to the settings controller
            [self.installedController removeFromParentViewController];
            [self.installedController.view removeFromSuperview];
            [self.troubleshootingController removeFromParentViewController];
            [self.troubleshootingController.view removeFromSuperview];
            
            [self addChildViewController:self.settingsController];
            [self.view addSubview:self.settingsController.view];
            
            [self.settingsController didMoveToParentViewController:self];
            [self.settingsController.view setFrame:self.view.bounds];
            
            break;
            
        default:
            break;
    }
}

@end
