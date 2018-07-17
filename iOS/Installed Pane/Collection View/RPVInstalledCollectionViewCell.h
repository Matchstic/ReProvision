//
//  RPVInstalledCollectionViewCell.h
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RPVInstalledCollectionViewCell : UICollectionViewCell

- (void)configureWithApplication:(id)application fallbackDisplayName:(NSString*)fallback andExpiryDate:(NSDate*)expiryDate;

@end
