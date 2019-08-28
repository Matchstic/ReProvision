//
//  RPVAccountViewController.m
//  iOS
//
//  Created by Matt Clarke on 07/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVAccountViewController.h"
#import "RPVAccount2FAViewController.h"
#import "RPVAccountTeamIDViewController.h"
#import "RPVAccountFinalController.h"
#import "RPVAccountChecker.h"

@interface RPVAccountViewController ()

@property (nonatomic, strong) NSArray *_interimTeamIDArray;

@end

@implementation RPVAccountViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.confirmButtonItem.enabled = NO;
    
    [self.passwordTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.emailTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    [self.navigationController.navigationBar setShadowImage:[UIImage new]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)present2FAViewController {
    [self performSegueWithIdentifier:@"present2FA" sender:nil];
    
    // Reset in case of a previous failure
    self.titleLabel.text = @"Apple ID";
    self.titleLabel.textColor = [UIColor blackColor];
    
    self.subtitleLabel.text = @"Sign in to the account you used for Cydia Impactor";
}

- (void)presentTeamIDViewControllerIfNecessaryWithTeamIDs:(NSArray*)teamids {
    self._interimTeamIDArray = teamids;
    
    if ([teamids count] == 1) {
        [self presentFinalController];
    } else {
        [self performSegueWithIdentifier:@"presentTeamIDController" sender:nil];
    }
}

- (void)presentFinalController {
    [self performSegueWithIdentifier:@"presentFinalController" sender:nil];
}

- (IBAction)didTapConfirmButton:(id)sender {
    // Check with Apple whether this email/password combo is correct.
    //  -- from output status, handle. i.e., segue to 2FA, show incorrect, or success handler.
    
    // Set right bar item to a spinning wheel
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinner.hidesWhenStopped = YES;
    [spinner startAnimating];
    
    [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithCustomView:spinner]];
    
    [[RPVAccountChecker sharedInstance] checkUsername:self.emailTextField.text withPassword:self.passwordTextField.text andCompletionHandler:^(NSString *failureReason, NSString *resultCode, NSArray *teamIDArray) {
       
        if (teamIDArray) {
            // TODO: Handle the Team ID array. If one element, no worries. Otherwise we need to ask the user
            // which team to use.
            // TODO: Once handled, we need to register the current device if so required to that Team ID.
            // TODO: Save Team ID and username/password combo
            // TODO: Un-present ourselves!
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentTeamIDViewControllerIfNecessaryWithTeamIDs:teamIDArray];
            });
        } else if ([resultCode isEqualToString:@"appSpecificRequired"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self present2FAViewController];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self changeUIToIncorrectStatus:failureReason];
            });
        }
        
        // Stop using a spinner.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationItem setRightBarButtonItem:self.confirmButtonItem];
        });
    }];
}

- (void)changeUIToIncorrectStatus:(NSString*)statusString {
    self.titleLabel.text = @"Failure";
    self.titleLabel.textColor = [UIColor redColor];
    
    self.subtitleLabel.text = statusString != nil ? statusString : @"Unknown error";
    
    // Reset input fields
    self.emailTextField.text = @"";
    [self.emailTextField becomeFirstResponder];
    
    self.passwordTextField.text = @"";
    
    // And disable button
    self.confirmButtonItem.enabled = NO;
}

////////////////////////////////////////////////////////
// UITextFieldDelegate
////////////////////////////////////////////////////////

- (void)textFieldDidChange:(id)sender {
    if ([self.emailTextField.text containsString:@"@"] && self.passwordTextField.text.length > 0) {
        self.confirmButtonItem.enabled = YES;
    } else {
        self.confirmButtonItem.enabled = NO;
    }
}

////////////////////////////////////////////////////////
// Segue Navigation
////////////////////////////////////////////////////////

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[[segue destinationViewController] class] isEqual:[RPVAccount2FAViewController class]]) {
        RPVAccount2FAViewController *twofaController = (RPVAccount2FAViewController*)[segue destinationViewController];
        
        // Setup 2FA controller with the current email address
        [twofaController setupWithEmailAddress:self.emailTextField.text];
    } else if ([[[segue destinationViewController] class] isEqual:[RPVAccountTeamIDViewController class]]) {
        // If Team ID controller, pass through the interim team ID array.
        RPVAccountTeamIDViewController *teamidController = (RPVAccountTeamIDViewController*)[segue destinationViewController];
        
        [teamidController setupWithDataSource:self._interimTeamIDArray username:self.emailTextField.text andPassword:self.passwordTextField.text];
    } else if ([[[segue destinationViewController] class] isEqual:[RPVAccountFinalController class]]) {
        // or if the final controller, send everything through!
        
        NSString *teamID = [[self._interimTeamIDArray firstObject] objectForKey:@"teamId"];
        NSString *username = self.emailTextField.text;
        NSString *password = self.passwordTextField.text;
        
        RPVAccountFinalController *finalController = (RPVAccountFinalController*)[segue destinationViewController];
        
        [finalController setupWithUsername:username password:password andTeamID:teamID];
    }
}

@end
