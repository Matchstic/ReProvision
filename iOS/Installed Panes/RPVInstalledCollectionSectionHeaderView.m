//
//  RPVInstalledCollectionSectionHeaderView.m
//  
//
//  Created by Matt Clarke on 09/01/2018.
//

#import "RPVInstalledCollectionSectionHeaderView.h"

@interface RPVInstalledCollectionSectionHeaderView ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UIView *seperatorLine;

@property (nonatomic, readwrite) NSInteger section;

@end

@implementation RPVInstalledCollectionSectionHeaderView

- (void)_configureViewsIfNecessary {
    if (!self.titleLabel) {
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.titleLabel.text = @"TITLE";
        self.titleLabel.font = [UIFont systemFontOfSize:18.6 weight:UIFontWeightHeavy];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        
        [self addSubview:self.titleLabel];
    }
    
    if (!self.button) {
        self.button = [UIButton buttonWithType:UIButtonTypeCustom];
        self.button.backgroundColor = [UIColor colorWithRed:240.0/255.0 green:240.0/255.0 blue:248.0/255.0 alpha:1.0];
        
        [self.button setTitle:@"BTN" forState:UIControlStateNormal];
        
        [self.button setTitleColor:[UIColor colorWithRed:0.0/255.0 green:122.0/255.0 blue:255.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        [self.button setTitleColor:[UIColor colorWithRed:0.0/255.0 green:122.0/255.0 blue:255.0/255.0 alpha:0.5] forState:UIControlStateHighlighted];
        
        self.button.titleLabel.font = [UIFont boldSystemFontOfSize:14];

        self.button.layer.cornerRadius = 28.0/2.0;
        
        [self.button addTarget:self action:@selector(_buttonWasTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:self.button];
    }
    
    if (!self.seperatorLine) {
        self.seperatorLine = [[UIView alloc] initWithFrame:CGRectZero];
        self.seperatorLine.backgroundColor = [UIColor colorWithRed:227.0/255.0 green:227.0/255.0 blue:227.0/255.0 alpha:1.0];
        
        [self addSubview:self.seperatorLine];
    }
}

- (void)_buttonWasTapped:(id)sender {
    
}

- (void)configureWithTitle:(NSString*)title buttonLabel:(NSString*)buttonLabel section:(NSInteger)section andDelegate:(id<RPVInstalledCollectionSectionHeaderDelegate>)delegate {
    [self _configureViewsIfNecessary];
    
    self.section = section;
    
    // Set title
    self.titleLabel.text = title;
    
    // Set button title
    [self.button setTitle:buttonLabel forState:UIControlStateNormal];
    
    // TODO: Set delegate
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // Layout our subviews.
    
    CGFloat buttonTextMargin = 20;
    CGFloat insetMargin = 20;
    
    self.seperatorLine.frame = CGRectMake(insetMargin, 0, self.frame.size.width - (insetMargin * 2), 0.5);
    
    [self.button sizeToFit];
    self.button.frame = CGRectMake(self.frame.size.width - insetMargin - self.button.frame.size.width - (buttonTextMargin * 2), self.frame.size.height/2 - 28/2, self.button.frame.size.width + (buttonTextMargin * 2), 28);
    
    self.titleLabel.frame = CGRectMake(insetMargin, 0, self.frame.size.width - self.button.frame.size.width - (3 * insetMargin), self.frame.size.height);
}

@end
