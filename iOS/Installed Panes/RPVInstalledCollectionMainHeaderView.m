//
//  RPVInstalledCollectionMainHeaderView.m
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVInstalledCollectionMainHeaderView.h"

@interface RPVInstalledCollectionMainHeaderView ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *dateLabel;

@end

static CGFloat titleSize = 36;
static CGFloat dateSize = 18;
static CGFloat inset = 20;

@implementation RPVInstalledCollectionMainHeaderView

- (void)_configureViewsIfNecessary {
    if (!self.titleLabel) {
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.titleLabel.text = @"TITLE";
        self.titleLabel.font = [UIFont systemFontOfSize:33 weight:UIFontWeightHeavy];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        
        [self addSubview:self.titleLabel];
    }

    if (!self.dateLabel) {
        self.dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.dateLabel.text = @"DATE";
        self.dateLabel.font = [UIFont boldSystemFontOfSize:12];
        self.dateLabel.textColor = [UIColor colorWithRed:142.0/255.0 green:142.0/255.0 blue:147.0/255.0 alpha:1.0];
        
        [self addSubview:self.dateLabel];
    }
}

- (void)configureWithTitle:(NSString*)title {
    [self _configureViewsIfNecessary];
    
    self.titleLabel.text = title;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.titleLabel.frame = CGRectMake(inset, self.frame.size.height - titleSize - (inset / 4), self.frame.size.width - (inset * 2), titleSize);
    
    self.dateLabel.frame = CGRectMake(inset, self.frame.size.height - self.titleLabel.frame.size.height - (inset / 2) - dateSize, self.frame.size.width - (inset * 2), dateSize);
}

@end
