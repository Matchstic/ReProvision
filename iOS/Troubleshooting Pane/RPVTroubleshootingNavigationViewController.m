//
//  RPVTroubleshootingNavigationViewController.m
//  iOS
//
//  Created by Matt Clarke on 04/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVTroubleshootingNavigationViewController.h"
#import "RPVTroubleshootingController.h"

@interface RPVTroubleshootingNavigationViewController ()

@end

@implementation RPVTroubleshootingNavigationViewController

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        
        if (@available(iOS 11.0, *)) {
            self.navigationBar.prefersLargeTitles = UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad ? YES : NO;
        }
        
        // Create root controller
        RPVTroubleshootingController *table = [[RPVTroubleshootingController alloc] init];
        [self setViewControllers:@[table] animated:NO];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //[self.navigationItem setTitle:@"About"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
