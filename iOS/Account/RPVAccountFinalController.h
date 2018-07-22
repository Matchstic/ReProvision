//
//  RPVAccountFinalController.h
//  iOS
//
//  Created by Matt Clarke on 08/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RPVAccountFinalController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *doneButton;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *certificatesExplanation;
@property (nonatomic, strong) NSMutableArray *dataSource;

- (void)setupWithUsername:(NSString*)username password:(NSString*)password andTeamID:(NSString*)teamID;

@end
