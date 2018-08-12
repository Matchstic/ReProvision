//
//  RPVInstalledSectionHeaderView.m
//  
//
//  Created by Matt Clarke on 09/01/2018.
//

#import "RPVInstalledSectionHeaderViewController.h"

@interface RPVInstalledSectionHeaderViewController ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UIView *seperatorLine;

@property (nonatomic, readwrite) NSInteger section;
@property (nonatomic, weak) id<RPVInstalledSectionHeaderDelegate> delegate;

@end

@implementation RPVInstalledSectionHeaderViewController

- (void)_configureViewsIfNecessary {
    if (!self.titleLabel) {
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.titleLabel.text = @"TITLE";
        self.titleLabel.font = [UIFont systemFontOfSize:30 weight:UIFontWeightRegular];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.textColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        
        [self.view addSubview:self.titleLabel];
    }
    
    if (!self.button) {
        self.button = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.button setTitle:@"BTN" forState:UIControlStateNormal];
        [self.button addTarget:self action:@selector(_buttonWasTapped:) forControlEvents:UIControlEventPrimaryActionTriggered];
        
        [self.view addSubview:self.button];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_signingDidBegin:) name:@"com.matchstic.reprovision/signingInProgress" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_signingDidComplete:) name:@"com.matchstic.reprovision/signingComplete" object:nil];
    
    // Setup focus guide for our button.
    [self _setupFocusGuide];
}

- (void)_setupFocusGuide {
    UIFocusGuide *guide = [[UIFocusGuide alloc] init];
    guide.preferredFocusedView = self.button;
    [self.view addLayoutGuide:guide];
    
    // Constraints
    [self.view addConstraints:@[
                                [guide.topAnchor constraintEqualToAnchor:self.view.topAnchor],
                                [guide.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
                                [guide.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
                                [guide.widthAnchor constraintEqualToAnchor:self.view.widthAnchor],
    ]];
}

- (void)_buttonWasTapped:(id)sender {
    [self.delegate didRecieveHeaderButtonInputWithSection:self.section];
}

// Disable button when signing is in progress!
- (void)_signingDidBegin:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.button.enabled = NO;
        //self.button.alpha = 0.5;
    });
}

// And re-enable if needed
- (void)_signingDidComplete:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.button.enabled = [self.delegate isButtonEnabledForSection:self.section];
        //self.button.alpha = self.button.enabled ? 1.0 : 0.5;
    });
}

- (void)requestNewButtonEnabledState {
    self.button.enabled = [self.delegate isButtonEnabledForSection:self.section];
    //self.button.alpha = self.button.enabled ? 1.0 : 0.5;
}

- (void)setInvertColours:(BOOL)invertColours {
    _invertColours = invertColours;
    
    if (invertColours) {
        self.titleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    } else {
        self.titleLabel.textColor = [UIColor colorWithWhite:0.0 alpha:0.75];
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
    //self.button.alpha = self.button.enabled ? 1.0 : 0.5;
    
    // Set delegate
    self.delegate = delegate;
}

- (UIView*)preferredFocusedView {
    return self.button;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // Layout our subviews.
    
    CGFloat buttonTextMargin = 20;
    CGFloat insetMargin = self.view.frame.size.width * 0.05;
    
    self.seperatorLine.frame = CGRectMake(insetMargin, 0, self.view.frame.size.width - (insetMargin * 2), 0.5);
    
    [self.button sizeToFit];
    self.button.frame = CGRectMake(self.view.frame.size.width - insetMargin - self.button.frame.size.width - (buttonTextMargin * 2), self.view.frame.size.height/2 - 60/2, self.button.frame.size.width + (buttonTextMargin * 2), 60);
    
    self.titleLabel.frame = CGRectMake(insetMargin, 0, self.view.frame.size.width - self.button.frame.size.width - 40, self.view.frame.size.height);
}

@end
