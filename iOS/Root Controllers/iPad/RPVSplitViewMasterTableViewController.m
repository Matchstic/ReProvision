//
//  RPVSplitViewMasterTableViewController.m
//  iOS
//
//  Created by Matt Clarke on 04/06/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVSplitViewMasterTableViewController.h"
#import "RPVResources.h"

@interface UINavigationBar (iOS11)
@property (nonatomic, readwrite) BOOL prefersLargeTitles;
@end

@interface RPVSplitViewMasterTableViewController ()
@end

@implementation RPVSplitViewMasterTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SplitMasterCell"];
    
    self.title = @"ReProvision";
    
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Handle login
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidRequestAccountViewController:) name:@"RPVDisplayAccountSignInController" object:nil];
    
    // Check if we need to present the account view based upon settings.
    // Check if we need to present the account view based upon settings.
    if (![RPVResources getUsername] ||
        [[RPVResources getUsername] isEqualToString:@""] ||
        ![[RPVResources getCredentialsVersion] isEqualToString:CURRENT_CREDENTIALS_VERSION])
        [self presentAccountViewControllerAnimated:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)userDidRequestAccountViewController:(id)sender {
    [self presentAccountViewControllerAnimated:YES];
}

- (void)presentAccountViewControllerAnimated:(BOOL)animated {
    [self performSegueWithIdentifier:animated ? @"presentAccountControllerAnimated" : @"presentAccountController" sender:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SplitMasterCell" forIndexPath:indexPath];
    
    // Configure the cell...
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"Installed";
            
            if (tableView.indexPathForSelectedRow.row == 0)
                cell.imageView.image = [UIImage imageNamed:@"installedActive"];
            else
                cell.imageView.image = [UIImage imageNamed:@"installed"];
            break;
        case 1:
            cell.textLabel.text = @"Troubleshooting";
            
            if (tableView.indexPathForSelectedRow.row == 1)
                cell.imageView.image = [UIImage imageNamed:@"troubleshootingActive"];
            else
                cell.imageView.image = [UIImage imageNamed:@"troubleshooting"];
            break;
        case 2:
            cell.textLabel.text = @"Settings";
            
            if (tableView.indexPathForSelectedRow.row == 2)
                cell.imageView.image = [UIImage imageNamed:@"settingsActive"];
            else
                cell.imageView.image = [UIImage imageNamed:@"settings"];
            break;
            
        default:
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Set the active cell images correctly
    for (int i = 0; i < [self tableView:tableView numberOfRowsInSection:0]; i++) {
        NSString *imageName = @"";
        
        switch (i) {
            case 0:
                imageName = @"installed";
                break;
            case 1:
                imageName = @"troubleshooting";
                break;
            case 2:
                imageName = @"settings";
                break;
                
            default:
                break;
        }
        
        if (i == indexPath.row) {
            imageName = [imageName stringByAppendingString:@"Active"];
        }
        
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
        cell.imageView.image = [UIImage imageNamed:imageName];
    }
    
    // Did select row at index! We don't deselect here.
    [self.detailViewController presentSelectedItem:indexPath.row];
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
