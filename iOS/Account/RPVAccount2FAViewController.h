//
//  RPVAccount2FAViewController.h
//  iOS
//
//  Created by Matt Clarke on 07/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RPVAccount2FAViewController : UIViewController

@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UILabel *subtitleLabel;

@property (strong, nonatomic) IBOutlet UITextField *passwordTextField;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *confirmBarButtonItem;

- (void)setupWithEmailAddress:(NSString*)emailAddress;

@end
