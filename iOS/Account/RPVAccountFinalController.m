//
//  RPVAccountFinalController.m
//  iOS
//
//  Created by Matt Clarke on 08/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVAccountFinalController.h"
#import "EEBackend.h"
#import "EEAppleServices.h"
#import "RPVResources.h"
#import "RPVAccountChecker.h"

@interface RPVAccountFinalController ()

@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSString *teamId;

@end

@implementation RPVAccountFinalController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Start checking with Apple for device registration!
    [self _checkDeviceRegistration];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupWithUsername:(NSString*)username password:(NSString*)password andTeamID:(NSString*)teamID {
    self.username = username;
    self.password = password;
    self.teamId = teamID;
}

/*- (void)_checkDevelopmentCertificates {
    self.titleLabel.text = @"Checking Signing Certificates";
    self.subtitleLabel.text = @"Verifying...";
    
    // TODO: Check whether the user needs to revoke an existing development certificate.
    // Could list teams and see if the current team ID is a free profile. If so, then if > 1 profiles need to revoke one.
    [EEAppleServices listAllDevelopmentCertificatesForTeamID:self.teamId withCompletionHandler:^(NSError *error, NSDictionary *dictionary) {
       
        
        
    }];
}*/

- (void)_checkDeviceRegistration {
    self.titleLabel.text = @"Checking Device Status";
    self.subtitleLabel.text = @"Verifying...";
    
    [[RPVAccountChecker sharedInstance] registerCurrentDeviceForTeamID:self.teamId withUsername:self.username password:self.password andCompletionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Error only happens if user already has registered this device!
            [self _storeUserDetails];
        });
    }];
}

- (void)_storeUserDetails {
    self.titleLabel.text = @"Storing Login Information";
    self.subtitleLabel.text = @"Working...";
    
    // Store details of the user to RPVResources
    [RPVResources storeUsername:self.username password:self.password andTeamID:self.teamId];
    
    [self performSelector:@selector(_done) withObject:nil afterDelay:2.0];
}

- (void)_done {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.titleLabel.text = @"Finished";
        self.subtitleLabel.text = @"Signed in successfully!";
        
        [self.activityIndicatorView stopAnimating];
        self.activityIndicatorView.hidden = YES;
        
        self.doneButton.enabled = YES;
    });
}

- (IBAction)_dismissAccountModal:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{}];
}

@end
