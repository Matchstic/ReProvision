//
//  RPVInstalledMainHeaderView.m
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVInstalledMainHeaderView.h"

@interface RPVInstalledMainHeaderView ()

@property (nonatomic, strong) UILabel *titleLabel;

@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

static CGFloat titleSize = 36;
static CGFloat dateSize = 18;
static CGFloat inset = 20;

@implementation RPVInstalledMainHeaderView

- (void)_configureViewsIfNecessary {
    if (!self.titleLabel) {
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.titleLabel.text = @"TITLE";
        self.titleLabel.font = [UIFont systemFontOfSize:33 weight:UIFontWeightBold];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.textColor = [UIColor whiteColor];
        
        [self addSubview:self.titleLabel];
    }

    if (!self.dateLabel) {
        self.dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.dateLabel.font = [UIFont boldSystemFontOfSize:12];
        self.dateLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        
        [self addSubview:self.dateLabel];
        
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"EEEE d MMMM"];
        
        self.dateLabel.text = [self _formattedDateForNow];
    }
}

- (NSString*)_formattedDateForNow {
    NSDate *now = [NSDate date];
    return [[self.dateFormatter stringFromDate:now] uppercaseString];
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
