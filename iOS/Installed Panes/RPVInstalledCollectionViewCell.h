//
//  RPVInstalledCollectionViewCell.h
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RPVInstalledCollectionViewCell : UICollectionViewCell

- (void)configureWithBundleIdentifier:(NSString*)bundleIdentifier displayName:(NSString*)displayName icon:(UIImage*)icon timeRemainingString:(NSString*)timeRemainingString;

@end
