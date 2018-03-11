//
//  RPVInstalledCollectionViewController.m
//  ReProvision
//
//  Created by Matt Clarke on 08/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVInstalledCollectionViewController.h"
#import "RPVInstalledCollectionMainHeaderView.h"
#import "RPVInstalledCollectionViewCell.h"
#import "RPVResources.h"

#import "RPVApplication.h"
#import "RPVApplicationDatabase.h"
#import "RPVApplicationSigning.h"
#import "RPVErrors.h"

@interface RPVInstalledCollectionViewController ()

@property (nonatomic, strong) UICollectionViewLayout *layout;
@property (nonatomic, strong) NSArray *expiringSoonDataSource;
@property (nonatomic, strong) NSArray *recentlySignedDataSource;

@end

@implementation RPVInstalledCollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // Register the main header
    [self.collectionView registerClass:[RPVInstalledCollectionMainHeaderView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"main.header"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Reload data sources on each view appear.
    [self _reloadDataSources];
}

//////////////////////////////////////////////////////////////////////////////////
// Collection View delegate methods.
//////////////////////////////////////////////////////////////////////////////////

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    RPVInstalledCollectionViewCell *cell = (RPVInstalledCollectionViewCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"installed.cell" forIndexPath:indexPath];
    
    cell.backgroundColor = [UIColor whiteColor];
    
    RPVApplication *application;
    NSString *fallbackString = @"";
    switch (indexPath.section) {
        case 1:
            if (self.expiringSoonDataSource.count > 0)
                application = [self.expiringSoonDataSource objectAtIndex:indexPath.row];
            else
                fallbackString = @"No applications are expiring soon";
            break;
        case 2:
            if (self.recentlySignedDataSource.count > 0)
                application = [self.recentlySignedDataSource objectAtIndex:indexPath.row];
            else
                fallbackString = @"No applications are recently signed";
            break;
        case 0:
        default:
            return 0;
    }
    
    NSString *timeRemainingString = @"";
    if (application) {
        BOOL warning = NO;
        timeRemainingString = [self _getFormattedTimeRemainingForExpirationDate:[application applicationExpiryDate] warning:&warning];
    }
    
    [cell configureWithBundleIdentifier:application.bundleIdentifier displayName:application ? [application applicationName] : fallbackString icon:[application applicationIcon] timeRemainingString:timeRemainingString];
    
    return cell;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    switch (section) {
        case 1:
            return self.expiringSoonDataSource.count > 0 ? self.expiringSoonDataSource.count : 1;
        case 2:
            return self.recentlySignedDataSource.count > 0 ? self.recentlySignedDataSource.count : 1;
        case 0:
        default:
            return 0;
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    
    if (section == 0) {
            return UIEdgeInsetsMake(0, 0, 0, 0);
    } else {
            return UIEdgeInsetsMake(5, 20, 20, 20);
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 1:
            return self.expiringSoonDataSource.count > 0 ? [(UICollectionViewFlowLayout*)collectionViewLayout itemSize] : CGSizeMake([UIScreen mainScreen].bounds.size.width - 40, 50);
        case 2:
            return self.recentlySignedDataSource.count > 0 ? [(UICollectionViewFlowLayout*)collectionViewLayout itemSize] : CGSizeMake([UIScreen mainScreen].bounds.size.width - 40, 50);
            
        default:
            return [(UICollectionViewFlowLayout*)collectionViewLayout itemSize];
    }
}


- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 3; // one for main header, 2 for content sections
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    
    CGSize referenceSize = [(UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout headerReferenceSize];
    
    if (section == 0) {
        referenceSize.height = referenceSize.height * 1.8;
    } else {
        referenceSize.height = referenceSize.height + 5;
    }
    
    return referenceSize;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *reusableview = nil;
    
    if (kind == UICollectionElementKindSectionHeader) {
        
        if (indexPath.section == 0) {
            RPVInstalledCollectionMainHeaderView *mainHeaderView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"main.header" forIndexPath:indexPath];
            
            [mainHeaderView configureWithTitle:@"Installed"];
            
            reusableview = mainHeaderView;
        } else {
            RPVInstalledCollectionSectionHeaderView *sectionHeaderView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"section.header" forIndexPath:indexPath];
            
            // Setup section header view
            switch (indexPath.section) {
                case 1:
                    [sectionHeaderView configureWithTitle:@"Expiring Soon" buttonLabel:@"SIGN" section:1 andDelegate:self];
                    break;
                case 2:
                    [sectionHeaderView configureWithTitle:@"Recently Signed" buttonLabel:@"SIGN" section:2 andDelegate:self];
                    break;
                    
                default:
                    break;
            }
            
            reusableview = sectionHeaderView;
        }
    }
    
    return reusableview;
}

//////////////////////////////////////////////////////////////////////////////////
// Header View delegate methods.
//////////////////////////////////////////////////////////////////////////////////

- (void)didRecieveHeaderButtonInputWithSection:(NSInteger)section {
    // Handle button input!
    
    [[RPVApplicationSigning sharedInstance] resignApplications:(section == 1) thresholdForExpiration:2 withTeamID:[RPVResources getTeamID] username:[RPVResources getUsername] password:[RPVResources getPassword] progressUpdateHandler:^(NSString *bundleIdentifier, int percent) {
        
        NSLog(@"'%@' at %d%%", bundleIdentifier, percent);
        
    } errorHandler:^(NSError *error, NSString *bundleIdentifier) {
        
        NSLog(@"'%@' had error: %@", bundleIdentifier, error);
        
    } andCompletionHandler:^(NSError *error) {
        
        if (!error) {
            NSLog(@"Success!");
        } else {
            NSLog(@"%@", error);
        }
        
    }];
}

- (BOOL)isButtonEnabledForSection:(NSInteger)section {
    switch (section) {
        case 1:
            return self.expiringSoonDataSource.count > 0;
        case 2:
            return self.recentlySignedDataSource.count > 0;
        default:
            return NO;
    }
}

//////////////////////////////////////////////////////////////////////////////////
// Helper methods.
//////////////////////////////////////////////////////////////////////////////////

- (void)_reloadDataSources {
    NSMutableArray *expiringSoon = [NSMutableArray array];
    NSMutableArray *recentlySigned = [NSMutableArray array];
    
    // TODO: MAKE THIS RESPECT USER SETTINGS!
    NSDate *now = [NSDate date];
    int thresholdForExpiration = 2; // days
    
    NSDate *expirationDate = [now dateByAddingTimeInterval:60 * 60 * 24 * thresholdForExpiration];
    
    if (![[RPVApplicationDatabase sharedInstance] getApplicationsWithExpiryDateBefore:&expiringSoon andAfter:&recentlySigned date:expirationDate forTeamID:[RPVResources getTeamID]]) {
        
        // :(
    } else {
        self.expiringSoonDataSource = expiringSoon;
        self.recentlySignedDataSource = recentlySigned;
        
        // Reload the collection view.
        [self.collectionView reloadData];
    }
}

- (RPVApplication*)_applicationForBundleIdentifier:(NSString*)bundleIdentifier {
    for (RPVApplication *app in self.expiringSoonDataSource) {
        if ([[app bundleIdentifier] isEqualToString:bundleIdentifier]) {
            return app;
        }
    }
    
    for (RPVApplication *app in self.recentlySignedDataSource) {
        if ([[app bundleIdentifier] isEqualToString:bundleIdentifier]) {
            return app;
        }
    }
    
    return nil;
}

- (UIImage*)_getApplicationIconForBundleIdentifier:(NSString*)bundleIdentifier {
    RPVApplication *app = [self _applicationForBundleIdentifier:bundleIdentifier];
    return [app applicationIcon];
}

- (NSString*)_getApplicationDisplayNameForBundleIdentifier:(NSString*)bundleIdentifier {
    RPVApplication *app = [self _applicationForBundleIdentifier:bundleIdentifier];
    return [app applicationName];
}

- (NSString*)_getFormattedTimeRemainingForExpirationDate:(NSDate*)expirationDate warning:(BOOL*)warningRequired {
    NSDate *now = [NSDate date];
    
    NSTimeInterval distanceBetweenDates = [expirationDate timeIntervalSinceDate:now];
    double secondsInAnHour = 3600;
    NSInteger hoursBetweenDates = distanceBetweenDates / secondsInAnHour;
    
    int days = (int)floor((CGFloat)hoursBetweenDates / 24.0);
    int minutes = distanceBetweenDates / 60;
    
    if (days > 0) {
        return [NSString stringWithFormat:@"%d day%@ remaining", days, days == 1 ? @"" : @"s"];
    } else if (hoursBetweenDates > 0) {
        // less than 24 hours, warning time.
        *warningRequired = YES;
        return [NSString stringWithFormat:@"%d hour%@ remaining", (int)hoursBetweenDates, hoursBetweenDates == 1 ? @"" : @"s"];
    } else if (minutes > 0){
        // less than 1 hour, warning time. (!!)
        *warningRequired = YES;
        return [NSString stringWithFormat:@"%d minute%@ remaining", minutes, minutes == 1 ? @"" : @"s"];
    } else {
        *warningRequired = YES;
        return @"Expired";
    }
}

@end
