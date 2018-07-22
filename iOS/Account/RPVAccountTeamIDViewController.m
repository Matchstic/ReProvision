//
//  RPVAccountTeamIDViewController.m
//  iOS
//
//  Created by Matt Clarke on 07/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVAccountTeamIDViewController.h"
#import "RPVAccountFinalController.h"

@interface RPVAccountTeamIDViewController ()

@property (nonatomic, strong) NSArray *dataSource;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;

@property (nonatomic, strong) NSString *selectedTeamID;

@end

@implementation RPVAccountTeamIDViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Setup tableView.
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableHeaderView = nil;
    self.tableView.tableFooterView = nil;
    
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupWithDataSource:(NSArray*)dataSource username:(NSString*)username andPassword:(NSString*)password {
    // If tableView already exists, then reload it entirely.
    self.dataSource = dataSource;
    self.username = username;
    self.password = password;
    
    [self.tableView reloadData];
}

#pragma mark - Table view delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"teamid.cell" forIndexPath:indexPath];
    
    NSString *teamName = @"";
    NSString *teamID = @"";
    
    // Grab Team ID info for this cell.
    NSDictionary *data = [self.dataSource objectAtIndex:indexPath.row];
    teamID = [data objectForKey:@"teamId"];
    teamName = [NSString stringWithFormat:@"%@ (%@)", [data objectForKey:@"name"], [data objectForKey:@"type"]];
    
    cell.textLabel.text = teamName;
    cell.detailTextLabel.text = teamID;
    
    // Add the checkmark if currently selected.
    if ([teamID isEqualToString:self.selectedTeamID]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    
    return cell;
}

// Handle selection of a given table cell, and enable the "Next" button when one becomes selected
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *data = [self.dataSource objectAtIndex:indexPath.row];
    self.selectedTeamID = [data objectForKey:@"teamId"];
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    self.nextButton.enabled = YES;
}

-(BOOL)tableView:(UITableView *)tableView shouldDrawTopSeparatorForSection:(NSInteger)section {
    return NO;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[[segue destinationViewController] class] isEqual:[RPVAccountFinalController class]]) {
        // if the final controller, send everything through!
        
        NSString *teamID = self.selectedTeamID;
        NSString *username = self.username;
        NSString *password = self.password;
        
        RPVAccountFinalController *finalController = (RPVAccountFinalController*)[segue destinationViewController];
        
        [finalController setupWithUsername:username password:password andTeamID:teamID];
    }
}


@end
