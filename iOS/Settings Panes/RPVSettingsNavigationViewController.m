//
//  RPVSettingsNavigationViewController.m
//  ReProvision
//
//  Created by Matt Clarke on 08/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVSettingsNavigationViewController.h"
#import "RPVSettingsController.h"

@interface RPVSettingsNavigationViewController ()

@end

@implementation RPVSettingsNavigationViewController

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {

        if (@available(iOS 11.0, *)) {
            self.navigationBar.prefersLargeTitles = YES;
        }
        
        // Create root controller
        RPVSettingsController *table = [[RPVSettingsController alloc] init];
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
