//
//  RPVInstalledCollectionViewController.m
//  ReProvision
//
//  Created by Matt Clarke on 08/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVInstalledCollectionViewController.h"
#import "RPVInstalledCollectionMainHeaderView.h"

@interface RPVInstalledCollectionViewController ()

@property (nonatomic, strong) UICollectionViewLayout *layout;

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

//////////////////////////////////////////////////////////////////////////////////
// Collection View delegate methods.
//////////////////////////////////////////////////////////////////////////////////

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"installed.cell" forIndexPath:indexPath];
    
    cell.backgroundColor = [UIColor whiteColor];
    
    return cell;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    switch (section) {
        case 1:
            return 2;
        case 2:
            return 2;
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
}

@end
