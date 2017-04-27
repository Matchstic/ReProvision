//
//  EEPackagesViewController.m
//  Extender Installer
//
//  Created by Matt Clarke on 14/04/2017.
//
//

#import "EEPackagesViewController.h"
#import "EEPackageDatabase.h"
#import "EEPackagesCell.h"
#import "EEResources.h"

@interface LSApplicationProxy : NSObject
- (id)localizedName;
+ (instancetype)applicationProxyForIdentifier:(NSString*)arg1;
- (id)primaryIconDataForVariant:(int)arg1;
- (id)iconDataForVariant:(int)arg1;
@end

@interface EEPackagesViewController ()

@property (nonatomic, strong) NSMutableArray *proxies;

@end

#define REUSE @"proxies.cell"

@implementation EEPackagesViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    
    if (self) {
        
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[self navigationItem] setTitle:@"Installed"];
    
    [self.tableView registerClass:[EEPackagesCell class] forCellReuseIdentifier:REUSE];
    self.tableView.allowsSelection = NO;
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"Re-sign" style:UIBarButtonItemStylePlain target:self action:@selector(_resignApplicationsClicked:)];
    self.navigationItem.leftBarButtonItem = anotherButton;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // We should reload each time we appear, as on-device files may have changed.
    [self generateData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (void)generateData {
    [[EEPackageDatabase sharedInstance] rebuildDatabase];
    
    NSArray *identifiers = [[EEPackageDatabase sharedInstance] retrieveAllTeamIDApplications];
    
    self.proxies = [NSMutableArray array];
    
    for (NSString* bundle in identifiers) {
        LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:bundle];
        [self.proxies addObject:proxy];
    }
    
    [self.tableView reloadData];
}

- (void)_resignApplicationsClicked:(id)sender {
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Application Re-Signing" message:@"Would you like to re-sign applications that are close to expiring?" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *attempt = [UIAlertAction actionWithTitle:@"Re-sign" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        BOOL hasCachedUser = [EEResources username] != nil;
        
        if (!hasCachedUser) {
            [EEResources signInWithCallback:^(BOOL signedIn) {
                if (signedIn) {
                    [self beginBackgroundResign];
                } else {
                    // Do nothing.
                }
            }];
        } else {
            [self beginBackgroundResign];
        }
        
    }];
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [controller dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [controller addAction:cancel];
    [controller addAction:attempt];
    
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)beginBackgroundResign {
    // Resign!
    UIApplication *application = [UIApplication sharedApplication];
    UIBackgroundTaskIdentifier __block bgTask = [application beginBackgroundTaskWithName:@"Cydia Extender Auto Sign" expirationHandler:^{
        
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Sign the downloaded applications in turn, and attempt installations.
        
        [[EEPackageDatabase sharedInstance] rebuildDatabase];
        [[EEPackageDatabase sharedInstance] resignApplicationsIfNecessaryWithTaskID:bgTask];
    });
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.proxies.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    EEPackagesCell *cell = [tableView dequeueReusableCellWithIdentifier:REUSE forIndexPath:indexPath];
    if (!cell) {
        cell = [[EEPackagesCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:REUSE];
    }
    
    LSApplicationProxy *proxy = [self.proxies objectAtIndex:indexPath.row];
    
    [cell setupWithProxy:proxy];
    
    cell.accessoryType = UITableViewCellAccessoryDetailButton;
    
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 75.0;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    LSApplicationProxy *proxy = [self.proxies objectAtIndex:indexPath.row];
    
    // We'll display a popup with some pertinant information regarding this application.
    
    NSString *message = [NSString stringWithFormat:@"// TODO:\nAdd information here!"];
    
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:[proxy localizedName] message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [controller dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [controller addAction:cancel];
    
    [self presentViewController:controller animated:YES completion:nil];
}

@end
