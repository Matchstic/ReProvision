//
//  RPVInstalledSectionHeaderView.m
//  
//
//  Created by Matt Clarke on 09/01/2018.
//

#import "RPVInstalledSectionHeaderView.h"

@interface RPVInstalledSectionHeaderView ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UIView *seperatorLine;

@property (nonatomic, readwrite) NSInteger section;
@property (nonatomic, weak) id<RPVInstalledSectionHeaderDelegate> delegate;

@end

@implementation RPVInstalledSectionHeaderView

- (void)_configureViewsIfNecessary {
    if (!self.titleLabel) {
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.titleLabel.text = @"TITLE";
        self.titleLabel.font = [UIFont systemFontOfSize:18.6 weight:UIFontWeightBold];
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
        [self.button addTarget:self action:@selector(_buttonWasHighlighted:) forControlEvents:UIControlEventTouchDown];
        [self.button addTarget:self action:@selector(_buttonNotHighlighted:) forControlEvents:UIControlEventTouchUpOutside];
        
        [self addSubview:self.button];
        
        self.showButton = YES;
    }
    
    if (!self.seperatorLine) {
        self.seperatorLine = [[UIView alloc] initWithFrame:CGRectZero];
        self.seperatorLine.backgroundColor = [UIColor colorWithRed:227.0/255.0 green:227.0/255.0 blue:227.0/255.0 alpha:1.0];
        
        [self addSubview:self.seperatorLine];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_signingDidBegin:) name:@"com.matchstic.reprovision/signingInProgress" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_signingDidComplete:) name:@"com.matchstic.reprovision/signingComplete" object:nil];
}

- (void)_buttonWasHighlighted:(id)sender {
    self.button.alpha = 0.75;
}

- (void)_buttonNotHighlighted:(id)sender {
    self.button.alpha = 1.0;
}

- (void)_buttonWasTapped:(id)sender {
    [self.delegate didRecieveHeaderButtonInputWithSection:self.section];
    [self _buttonNotHighlighted:nil]; // Reset background colour
}

// Disable button when signing is in progress!
- (void)_signingDidBegin:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.button.enabled = NO;
        self.button.alpha = 0.5;
    });
}

// And re-enable if needed
- (void)_signingDidComplete:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.button.enabled = [self.delegate isButtonEnabledForSection:self.section];
        self.button.alpha = self.button.enabled ? 1.0 : 0.5;
    });
}

- (void)requestNewButtonEnabledState {
    self.button.enabled = [self.delegate isButtonEnabledForSection:self.section];
    self.button.alpha = self.button.enabled ? 1.0 : 0.5;
}

- (void)setInvertColours:(BOOL)invertColours {
    _invertColours = invertColours;
    
    if (invertColours) {
        self.titleLabel.textColor = [UIColor whiteColor];
        
        self.button.backgroundColor = [UIColor whiteColor];
        self.tintColor = [UIColor colorWithRed:147.0/255.0 green:99.0/255.0 blue:207.0/255.0 alpha:1.0];
        [self.button setTitleColor:self.tintColor forState:UIControlStateNormal];
        [self.button setTitleColor:self.tintColor forState:UIControlStateHighlighted];
    } else {
        self.titleLabel.textColor = [UIColor blackColor];
        self.button.backgroundColor = [UIColor whiteColor];
        
        // Add gradient
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.frame = self.button.bounds;
        gradient.cornerRadius = self.button.layer.cornerRadius;
        
        UIColor *startColor = [UIColor colorWithRed:147.0/255.0 green:99.0/255.0 blue:207.0/255.0 alpha:1.0];
        UIColor *endColor = [UIColor colorWithRed:116.0/255.0 green:158.0/255.0 blue:201.0/255.0 alpha:1.0];
        gradient.colors = @[(id)startColor.CGColor, (id)endColor.CGColor];
        gradient.startPoint = CGPointMake(1.0, 0.5);
        gradient.endPoint = CGPointMake(0.0, 0.5);
        
        [self.button.layer insertSublayer:gradient atIndex:0];
        
        // Button colouration
        [self.button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
        
        self.seperatorLine.hidden = YES;
    }
}

- (void)configureWithTitle:(NSString*)title buttonLabel:(NSString*)buttonLabel section:(NSInteger)section andDelegate:(id<RPVInstalledSectionHeaderDelegate>)delegate {
    [self _configureViewsIfNecessary];
    
    self.section = section;
    
    // Set title
    self.titleLabel.text = title;
    
    // Set button title and enabled state
    [self.button setTitle:buttonLabel forState:UIControlStateNormal];
    self.button.enabled = [self.delegate isButtonEnabledForSection:section];
    self.button.alpha = self.button.enabled ? 1.0 : 0.5;
    
    // Set delegate
    self.delegate = delegate;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // Layout our subviews.
    
    CGFloat buttonTextMargin = 20;
    CGFloat insetMargin = 20;
    
    self.seperatorLine.frame = CGRectMake(insetMargin, 0, self.frame.size.width - (insetMargin * 2), 0.5);
    
    [self.button sizeToFit];
    self.button.frame = CGRectMake(self.frame.size.width - insetMargin - self.button.frame.size.width - (buttonTextMargin * 2), self.frame.size.height/2 - 28/2, self.button.frame.size.width + (buttonTextMargin * 2), 28);
    
    for (CALayer *layer in self.button.layer.sublayers) {
        layer.frame = self.button.bounds;
    }
    
    self.titleLabel.frame = CGRectMake(insetMargin, 0, self.frame.size.width - self.button.frame.size.width - (3 * insetMargin), self.frame.size.height);
    
    self.button.hidden = !self.showButton;
}

@end
