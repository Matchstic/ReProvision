//
//  SecondViewController.m
//  reprovision.tvos
//
//  Created by Matt Clarke on 07/08/2018.
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
        // Create root controller
        RPVSettingsController *table = [[RPVSettingsController alloc] init];
        [self setViewControllers:@[table] animated:NO];
    }
    
    return self;
}

@end
