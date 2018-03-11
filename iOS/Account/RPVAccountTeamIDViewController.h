//
//  RPVAccountTeamIDViewController.h
//  iOS
//
//  Created by Matt Clarke on 07/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RPVAccountTeamIDViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *nextButton;

- (void)setupWithDataSource:(NSArray*)dataSource username:(NSString*)username andPassword:(NSString*)password;

@end
