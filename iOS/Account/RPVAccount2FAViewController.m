//
//  RPVAccount2FAViewController.m
//  iOS
//
//  Created by Matt Clarke on 07/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVAccount2FAViewController.h"
#import "RPVAccountTeamIDViewController.h"
#import "RPVAccountFinalController.h"
#import "RPVAccountChecker.h"

@interface RPVAccount2FAViewController ()

@property (nonatomic, strong) NSString *emailAddress;
@property (nonatomic, strong) NSArray *_interimTeamIDArray;
@property (nonatomic, strong) NSURLCredential *credentials;
@property (nonatomic, readwrite) BOOL _requested2FACode;

@end

@implementation RPVAccount2FAViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.passwordTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    // Handle colour
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        self.titleLabel.textColor = [UIColor labelColor];
        self.subtitleLabel.textColor = [UIColor labelColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
        self.titleLabel.textColor = [UIColor blackColor];
        self.subtitleLabel.textColor = [UIColor blackColor];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    [self.navigationController.navigationBar setShadowImage:[UIImage new]];
    
    if (!self._requested2FACode) {
        [[RPVAccountChecker sharedInstance] requestLoginCodeWithCompletionHandler:^(NSError *error) {
            if (error) {
                NSString *failureReason = [NSString stringWithFormat:@"Failed to request 2FA code: %@", error.localizedDescription];
                [self changeUIToIncorrectStatus:failureReason];
            }
            
            self._requested2FACode = YES;
        }];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)presentTeamIDViewControllerIfNecessaryWithTeamIDs:(NSArray*)teamids credentials:(NSURLCredential*)credential {
    self._interimTeamIDArray = teamids;
    self.credentials = credential;
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
    //  -- from output status, handle. i.e., show incorrect, or success handler.
    
    // Set right bar item to a spinning wheel
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinner.hidesWhenStopped = YES;
    if (@available(iOS 13.0, *)) {
        spinner.color = [UIColor labelColor];
    }
    [spinner startAnimating];
    
    [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithCustomView:spinner]];

    // Handle 2FA login code for the given credentials
    long long code = [self.passwordTextField.text longLongValue];
    
    [[RPVAccountChecker sharedInstance] validateLoginCode:code withCompletionHandler:^(NSString *failureReason, NSString *resultCode, NSArray *teamIDArray, NSURLCredential *credential) {
        
        if (teamIDArray) {
            // Present the Team ID controller if necessary!
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentTeamIDViewControllerIfNecessaryWithTeamIDs:teamIDArray credentials:credential];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self changeUIToIncorrectStatus:failureReason];
            });
        }
        
        // Stop using a spinner.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationItem setRightBarButtonItem:self.confirmBarButtonItem];
        });
    }];
}

- (void)changeUIToIncorrectStatus:(NSString*)statusString {
    self.titleLabel.text = @"Failure";
    self.titleLabel.textColor = [UIColor redColor];
    
    self.subtitleLabel.text = statusString;

    // Reset
    self.passwordTextField.text = @"";
    
    // And disable button
    self.confirmBarButtonItem.enabled = NO;
}

- (void)setupWithEmailAddress:(NSString*)emailAddress {
    self.emailAddress = emailAddress;
}

////////////////////////////////////////////////////////
// UITextFieldDelegate
////////////////////////////////////////////////////////

- (void)textFieldDidChange:(id)sender {
    if (self.passwordTextField.text.length > 0) {
        self.confirmBarButtonItem.enabled = YES;
    } else {
        self.confirmBarButtonItem.enabled = NO;
    }
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[[segue destinationViewController] class] isEqual:[RPVAccountTeamIDViewController class]]) {
        // If Team ID controller, pass through the interim team ID array.
        RPVAccountTeamIDViewController *teamidController = (RPVAccountTeamIDViewController*)[segue destinationViewController];
        
        [teamidController setupWithDataSource:self._interimTeamIDArray username:self.emailAddress andPassword:self.passwordTextField.text];
    } else if ([[[segue destinationViewController] class] isEqual:[RPVAccountFinalController class]]) {
        // or if the final controller, send everything through!
        
        NSString *teamID = [[self._interimTeamIDArray firstObject] objectForKey:@"teamId"];
        NSString *username = self.credentials.user;
        NSString *password = self.credentials.password;
        
        RPVAccountFinalController *finalController = (RPVAccountFinalController*)[segue destinationViewController];
        
        [finalController setupWithUsername:username password:password andTeamID:teamID];
    }
}

@end
