//
//  RPVStickyScrollView.m
//  tvOS
//
//  Created by Matt Clarke on 11/08/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVStickyScrollView.h"

@implementation RPVStickyScrollView

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    if (contentOffset.y < self.stickyYPosition) {
        return;
    }
    
    [super setContentOffset:contentOffset animated:animated];
}

- (void)setContentOffset:(CGPoint)contentOffset {
    if (contentOffset.y < self.stickyYPosition) {
        return;
    }
    
    [super setContentOffset:contentOffset];
}

@end
