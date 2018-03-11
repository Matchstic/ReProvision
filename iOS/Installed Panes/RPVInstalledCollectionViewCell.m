//
//  RPVInstalledCollectionViewCell.m
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVInstalledCollectionViewCell.h"
#import "UIImage+ColorArt.h"
#import "CKBlurView.h"

@interface RPVInstalledCollectionViewCell ()

@property (nonatomic, readwrite) BOOL noApplicationsInThisSection;

@property (nonatomic, strong) UIView *highlightingView;

// Content view.
@property (nonatomic, strong) UIImageView *smallIcon;
@property (nonatomic, strong) UIImageView *largeIcon;
@property (nonatomic, strong) CKBlurView *blurView;

@property (nonatomic, strong) UILabel *displayNameLabel;
@property (nonatomic, strong) UILabel *bundleIdentifierLabel;

@property (nonatomic, strong) UIImageView *timeRemainingIcon;
@property (nonatomic, strong) UILabel *timeRemainingLabel;

@end

@implementation RPVInstalledCollectionViewCell

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        // Corner radius
        self.layer.cornerRadius = 12.5;
        
        // Dropshadow
        self.layer.shadowRadius = 9;
        self.layer.shadowColor = [UIColor grayColor].CGColor;
        self.layer.shadowOpacity = 0.2;
        self.layer.shadowOffset = CGSizeZero;
        
        // Highlighting view needs to always be on top to correctly darken content.
        self.highlightingView = [[UIView alloc] initWithFrame:CGRectZero];
        self.highlightingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.1];
        self.highlightingView.hidden = YES;
        self.highlightingView.layer.cornerRadius = self.layer.cornerRadius;
        
        [self addSubview:self.highlightingView];
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (!self.noApplicationsInThisSection) {
        self.highlightingView.frame = self.bounds;
        
        // Content
        self.largeIcon.transform = CGAffineTransformIdentity;
        self.largeIcon.frame = CGRectMake(0, 0, 100, 100);
        self.largeIcon.center = CGPointMake(self.contentView.frame.size.width - 25, 25);
        self.largeIcon.transform = CGAffineTransformMakeRotation(0.523599);
        
        self.blurView.frame = CGRectMake(0, 0, self.contentView.frame.size.width, self.contentView.frame.size.height);
        
        CGFloat xInset = 10;
        CGFloat yInset = 10;
        
        self.smallIcon.frame = CGRectMake(xInset, yInset, 26, 26);
        yInset += self.smallIcon.frame.size.height + 10;
        
        self.displayNameLabel.frame = CGRectMake(xInset, yInset, self.contentView.frame.size.width - (xInset*2), 20);
        
        yInset += self.displayNameLabel.frame.size.height;
        
        self.bundleIdentifierLabel.frame = CGRectMake(xInset, yInset, self.contentView.frame.size.width - (xInset*2), 20);
        
        // Time remaining.
        self.timeRemainingIcon.frame = CGRectMake(xInset, self.contentView.frame.size.height - 10 - self.timeRemainingIcon.frame.size.height, self.timeRemainingIcon.frame.size.width, self.timeRemainingIcon.frame.size.height);
        
        self.timeRemainingLabel.frame = CGRectMake(xInset + self.timeRemainingIcon.frame.size.width + 10, self.timeRemainingIcon.frame.origin.y, self.contentView.frame.size.width - (xInset*3) - self.timeRemainingIcon.frame.size.width, self.timeRemainingIcon.frame.size.height);
    } else {
        self.displayNameLabel.frame = self.contentView.bounds;
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    self.highlightingView.hidden = !highlighted;
    [self setNeedsDisplay];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    // Clear anything in the cell.
}

- (void)_setupUIIfNecessary {
    if (!self.largeIcon) {
        self.largeIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
        
        [self.contentView addSubview:self.largeIcon];
    }
    
    if (!self.blurView) {
        self.blurView = [[CKBlurView alloc] initWithFrame:CGRectZero];
        self.blurView.blurEdges = YES;
        self.blurView.blurRadius = 5.0;
        
        [self.contentView addSubview:self.blurView];
    }
    
    if (!self.smallIcon) {
        self.smallIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
        
        [self.contentView addSubview:self.smallIcon];
    }
    
    if (!self.displayNameLabel) {
        self.displayNameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        
        self.displayNameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        self.displayNameLabel.text = @"DISPLAY_NAME";
        self.displayNameLabel.numberOfLines = 0;
        
        [self.contentView addSubview:self.displayNameLabel];
    }
    
    if (!self.bundleIdentifierLabel) {
        self.bundleIdentifierLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        
        self.bundleIdentifierLabel.text = @"BUNDLE_IDENTIFIER";
        self.bundleIdentifierLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
        
        [self.contentView addSubview:self.bundleIdentifierLabel];
    }
    
    if (!self.timeRemainingIcon) {
        self.timeRemainingIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"TimeRemaining.png"]];
        [self.contentView addSubview:self.timeRemainingIcon];
    }
    
    if (!self.timeRemainingLabel) {
        self.timeRemainingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        
        self.timeRemainingLabel.text = @"TIME_REMAINING";
        self.timeRemainingLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        
        [self.contentView addSubview:self.timeRemainingLabel];
    }
    
    // Reset text colours if needed
    self.displayNameLabel.textColor = [UIColor whiteColor];
    self.displayNameLabel.textAlignment = NSTextAlignmentLeft;
    
    
    self.bundleIdentifierLabel.textColor = [UIColor whiteColor];
    self.timeRemainingLabel.textColor = [UIColor whiteColor];
    
    // Reset hidden state if needed
    self.largeIcon.hidden = NO;
    self.blurView.hidden = NO;
    self.smallIcon.hidden = NO;
    self.bundleIdentifierLabel.hidden = NO;
    self.timeRemainingIcon.hidden = NO;
    self.timeRemainingLabel.hidden = NO;
    
    self.contentView.clipsToBounds = YES;
    self.contentView.layer.cornerRadius = 12.5;
}

- (void)configureWithBundleIdentifier:(NSString*)bundleIdentifier displayName:(NSString*)displayName icon:(UIImage*)icon timeRemainingString:(NSString*)timeRemainingString {
    
    [self _setupUIIfNecessary];
    
    if (!bundleIdentifier) {
        // No application to display
        self.displayNameLabel.textColor = [UIColor grayColor];
        self.displayNameLabel.textAlignment = NSTextAlignmentCenter;
        
        // Set hidden state
        self.largeIcon.hidden = YES;
        self.smallIcon.hidden = YES;
        self.bundleIdentifierLabel.hidden = YES;
        self.timeRemainingIcon.hidden = YES;
        self.timeRemainingLabel.hidden = YES;
        self.blurView.hidden = YES;
        
        self.contentView.backgroundColor = [UIColor whiteColor];
        
        self.layer.shadowRadius = 0;
        
        self.noApplicationsInThisSection = YES;
    } else {
        self.noApplicationsInThisSection = NO;
        
        self.layer.shadowRadius = 9;
        
        // Setup colouration.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            SLColorArt *colourArt = [icon colorArt];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.contentView.backgroundColor = [colourArt backgroundColor];
                //self.displayNameLabel.textColor = [colourArt primaryColor];
                //self.bundleIdentifierLabel.textColor = [colourArt secondaryColor];
                //self.timeRemainingLabel.textColor = [colourArt detailColor];
            });
        });
    }
    
    // Setup values
    self.smallIcon.image = icon;
    self.largeIcon.image = icon;
    
    self.displayNameLabel.text = displayName;
    self.bundleIdentifierLabel.text = bundleIdentifier;
    
    self.timeRemainingLabel.text = timeRemainingString;
}

@end
