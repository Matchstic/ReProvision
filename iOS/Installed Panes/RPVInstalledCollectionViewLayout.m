//
//  RPVInstalledCollectionViewLayout.m
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVInstalledCollectionViewLayout.h"

static NSInteger numberOfColumns = 2;

@implementation RPVInstalledCollectionViewLayout

- (instancetype)init {
    self = [super init];
    if (self) {
        self.minimumLineSpacing = 1.0;
        self.minimumInteritemSpacing = 1.0;
        self.scrollDirection = UICollectionViewScrollDirectionVertical;
    }
    return self;
}

- (CGSize)itemSize {
    // We want items that are in aspect ratio 5:6 in width to height.
    CGFloat itemTotalWidth = CGRectGetWidth(self.collectionView.frame) - self.sectionInset.left - self.sectionInset.right - ((numberOfColumns - 1) * self.sectionInset.left);
    
    CGFloat itemWidth = itemTotalWidth / numberOfColumns;
    
    CGFloat itemHeight = (itemWidth/5) * 6;
    
    return CGSizeMake(itemWidth, itemHeight);
}

@end
