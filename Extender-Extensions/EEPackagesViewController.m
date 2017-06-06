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
@property (nonatomic, readonly) long bundleModTime;
@property (nonatomic, readonly) NSNumber *staticDiskUsage;
@property (nonatomic, readonly) NSString *minimumSystemVersion;
- (id)localizedName;
+ (instancetype)applicationProxyForIdentifier:(NSString*)arg1;
- (id)primaryIconDataForVariant:(int)arg1;
- (id)iconDataForVariant:(int)arg1;
@end

@interface EEPackagesViewController ()

@property (nonatomic, strong) NSMutableArray *proxies;

@end

#define REUSE @"proxies.cell"
#define REUSE2 @"noproxies.cell"

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
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:REUSE2];
    self.tableView.allowsSelection = NO;
    
    // If there is no Team ID saved, we disable this button.
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"Re-sign" style:UIBarButtonItemStylePlain target:self action:@selector(_resignApplicationsClicked:)];
    self.navigationItem.leftBarButtonItem = anotherButton;
    self.navigationItem.leftBarButtonItem.enabled = [EEResources getTeamID] != nil;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // We should reload each time we appear, as on-device files may have changed.
    [self generateData:nil];
    
    // If there is a Team ID saved, set the "Re-sign" button to enabled.
    self.navigationItem.leftBarButtonItem.enabled = [EEResources getTeamID] != nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(generateData:) name:@"EEDidSignApplication" object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (void)generateData:(id)notification {
    [[EEPackageDatabase sharedInstance] rebuildDatabase];
    
    NSArray *identifiers = [[EEPackageDatabase sharedInstance] retrieveAllTeamIDApplications];
    
    self.proxies = [NSMutableArray array];
    
    for (NSString* bundle in identifiers) {
        LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:bundle];
        [self.proxies addObject:proxy];
    }
    
    // We now need to order the proxies based upon localised display name.
    self.proxies = [[[self.proxies copy] sortedArrayUsingComparator:^NSComparisonResult(LSApplicationProxy *obj1, LSApplicationProxy *obj2) {
        return [[obj1 localizedName] compare:[obj2 localizedName] options:NSNumericSearch];
    }] mutableCopy];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)_resignApplicationsClicked:(id)sender {
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Application Re-signing" message:@"Would you like to re-sign all applications?" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *attempt = [UIAlertAction actionWithTitle:@"Re-sign" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        BOOL hasCachedUser = [EEResources username] != nil;
        
        if (!hasCachedUser) {
            [EEResources signInWithCallback:^(BOOL signedIn, NSString *username) {
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
        [[EEPackageDatabase sharedInstance] resignApplicationsIfNecessaryWithTaskID:bgTask andCheckExpiry:NO];
    });
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // If there is no Team ID saved, we display a single cell stating as such.
    return [EEResources getTeamID] != nil ? self.proxies.count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // If there is no Team ID saved, we use a UITableViewCell and set it's text and textColor.
    if (![EEResources getTeamID]) {
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:REUSE2];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:REUSE];
        }
        
        cell.textLabel.text = @"Sign in to view applications.";
        cell.textLabel.textColor = [UIColor grayColor];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    } else {
    
        EEPackagesCell *cell = [tableView dequeueReusableCellWithIdentifier:REUSE forIndexPath:indexPath];
        if (!cell) {
            cell = [[EEPackagesCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:REUSE];
        }
    
        LSApplicationProxy *proxy = [self.proxies objectAtIndex:indexPath.row];
    
        [cell setupWithProxy:proxy];
    
        cell.accessoryType = UITableViewCellAccessoryDetailButton;
    
        return cell;
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // If there is no Team ID saved, we use the default height of 44.0f.
    return [EEResources getTeamID] != nil ? 75.0 : 44.0;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    LSApplicationProxy *proxy = [self.proxies objectAtIndex:indexPath.row];
    
    // We'll display a popup with some pertinant information regarding this application.
    
    // staticDiskUsage (size in bytes)
    // minimumSystemVersion
    // installed time via bundleModTime.
    
    NSDate *bundleModifiedTimestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:proxy.bundleModTime];
    
    CGFloat megabytes = [proxy.staticDiskUsage floatValue]/1024.0/1024.0;
    
    NSString *message = [NSString stringWithFormat:@"\nLast Signed Time\n%@\n\nInstall Size\n%.2f MB\n\nMinimum System Version\niOS %@", bundleModifiedTimestamp, megabytes, proxy.minimumSystemVersion];
    
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:[proxy localizedName] message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [controller dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [controller addAction:cancel];
    
    [self presentViewController:controller animated:YES completion:nil];
}

@end
