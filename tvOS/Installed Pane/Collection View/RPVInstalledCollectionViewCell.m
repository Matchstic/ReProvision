//
//  RPVInstalledCollectionViewCell.m
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVInstalledCollectionViewCell.h"
#import "RPVApplication.h"
#import "RPVResources.h"

//#import <MBCircularProgressBarView.h>
#import <MarqueeLabel.h>

#define IS_IPAD UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad

@interface RPVInstalledCollectionViewCell ()

@property (nonatomic, readwrite) BOOL noApplicationsInThisSection;
@property (nonatomic, readwrite) BOOL isObserving;

@property (nonatomic, strong) NSDate *expiryDate;
@property (nonatomic, strong) NSTimer *expiryUpdateTimer;

// Content view.
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIImageView *icon;

@property (nonatomic, strong) MarqueeLabel *displayNameLabel;
@property (nonatomic, strong) MarqueeLabel *bundleIdentifierLabel;
@property (nonatomic, strong) NSString *bundleIdentifier;

@property (nonatomic, strong) MarqueeLabel *timeRemainingLabel;

@property (nonatomic, strong) MarqueeLabel *percentCompleteLabel;
//@property (nonatomic, strong) MBCircularProgressBarView *progressBar;

@property (nonatomic, strong) UIView *notificationView;

@end

@implementation RPVInstalledCollectionViewCell

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        // Corner radius
        self.layer.cornerRadius = 12.5;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_onSigningStatusUpdate:) name:@"com.matchstic.reprovision/signingUpdate" object:nil];
    }
    
    return self;
}

- (void)_onSigningStatusUpdate:(NSNotification*)notification {
    NSString *bundleIdentifier = [[notification userInfo] objectForKey:@"bundleIdentifier"];
    int percent = [[[notification userInfo] objectForKey:@"percent"] intValue];
    
    NSLog(@"**** Signing update: %@", [notification userInfo]);
    
    if ([bundleIdentifier isEqualToString:self.bundleIdentifier]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (percent > 0) {
                self.percentCompleteLabel.hidden = NO;
                //self.progressBar.hidden = NO;
                
                self.timeRemainingLabel.hidden = YES;
            }
            
            // Update progess bar!
            [UIView animateWithDuration:percent == 0 ? 0.0 : 0.35 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                //self.progressBar.value = percent;
                self.percentCompleteLabel.text = [NSString stringWithFormat:@"%d%% complete", percent];
            } completion:^(BOOL finished) {
                if (finished && percent == 100) {
                    self.percentCompleteLabel.hidden = YES;
                    //self.progressBar.hidden = YES;
                    
                    self.timeRemainingLabel.hidden = NO;
                }
            }];
        });
    }
}

- (void)onExpiryUpdateTimerFired:(id)sender {
    if (!self.expiryDate)
        return;
    
    self.timeRemainingLabel.text = [RPVResources getFormattedTimeRemainingForExpirationDate:self.expiryDate];
    
    // Relayout to handle this.
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.blurView.frame = self.contentView.bounds;
    
    if (!self.noApplicationsInThisSection) {
        CGFloat xInset = 15;
        CGFloat yInset = 10;
        
        self.icon.frame = CGRectMake(0, 0, self.contentView.frame.size.width, (self.contentView.frame.size.width / 400.0) * 240);
        
        yInset += self.icon.frame.size.height + 5;
        
        self.displayNameLabel.frame = CGRectMake(xInset, yInset, self.contentView.frame.size.width - (xInset*2), 28);
        
        yInset += self.displayNameLabel.frame.size.height + 5;
        
        self.bundleIdentifierLabel.frame = CGRectMake(xInset, yInset, self.contentView.frame.size.width - (xInset*2), 24);
        
        yInset += self.bundleIdentifierLabel.frame.size.height + 7;
        
        // Time remaining.
        self.timeRemainingLabel.frame = CGRectMake(xInset, yInset, self.contentView.frame.size.width - (xInset*2), 22);
        
        // Percent of signing.
        //self.progressBar.frame = CGRectMake(xInset, self.contentView.frame.size.height - (IS_IPAD ? 33 : 28), 20, 20);
        //self.percentCompleteLabel.frame = CGRectMake(xInset + self.progressBar.frame.size.width + 7, self.contentView.frame.size.height - (IS_IPAD ? 33 : 28), self.contentView.frame.size.width - (xInset*2) - self.progressBar.frame.size.width - 7, 20);
        
        self.notificationView.frame = self.contentView.bounds;
    } else {
        self.displayNameLabel.frame = self.contentView.bounds;
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    // Clear anything in the cell.
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    
    [coordinator addCoordinatedAnimations:^{
        if (self.isFocused) {
            self.transform = CGAffineTransformMakeScale(1.05, 1.05);
            self.layer.shadowOpacity = 0.25;
        } else {
            self.transform = CGAffineTransformMakeScale(1.0, 1.0);
            self.layer.shadowOpacity = 0.0;
        }
    } completion:^{
        
    }];
}

- (void)_setupUIIfNecessary {
    if (!self.isObserving) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_onSigningStatusUpdate:) name:@"com.matchstic.reprovision/signingUpdate" object:nil];
    }
    
    if (!self.blurView) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        
        self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        
        [self.contentView addSubview:self.blurView];
    }
    
    if (!self.icon) {
        self.icon = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.icon.backgroundColor = [UIColor lightGrayColor];
        
        [self.blurView.contentView addSubview:self.icon];
    }
    
    if (!self.displayNameLabel) {
        self.displayNameLabel = [[MarqueeLabel alloc] initWithFrame:CGRectZero];
        
        self.displayNameLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightRegular];
        self.displayNameLabel.text = @"DISPLAY_NAME";
        self.displayNameLabel.numberOfLines = 0;
        
        // MarqueeLabel specific
        self.displayNameLabel.fadeLength = 8.0;
        self.displayNameLabel.trailingBuffer = 10.0;
        
        [self.blurView.contentView addSubview:self.displayNameLabel];
    }
    
    if (!self.bundleIdentifierLabel) {
        self.bundleIdentifierLabel = [[MarqueeLabel alloc] initWithFrame:CGRectZero];
        
        self.bundleIdentifierLabel.text = @"BUNDLE_IDENTIFIER";
        self.bundleIdentifierLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightRegular];
        
        // MarqueeLabel specific
        self.bundleIdentifierLabel.fadeLength = 8.0;
        self.bundleIdentifierLabel.trailingBuffer = 10.0;
        
        [self.blurView.contentView addSubview:self.bundleIdentifierLabel];
    }
    
    if (!self.timeRemainingLabel) {
        self.timeRemainingLabel = [[MarqueeLabel alloc] initWithFrame:CGRectZero];
        
        self.timeRemainingLabel.text = @"TIME_REMAINING";
        self.timeRemainingLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
        
        // MarqueeLabel specific
        self.timeRemainingLabel.fadeLength = 8.0;
        self.timeRemainingLabel.trailingBuffer = 10.0;
        
        [self.blurView.contentView addSubview:self.timeRemainingLabel];
    }
    
    if (!self.percentCompleteLabel) {
        self.percentCompleteLabel = [[MarqueeLabel alloc] initWithFrame:CGRectZero];
        
        self.percentCompleteLabel.text = @"0% complete";
        self.percentCompleteLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightMedium];
        self.percentCompleteLabel.hidden = YES;
        self.percentCompleteLabel.textColor = [UIColor darkGrayColor];
        
        // MarqueeLabel specific
        self.percentCompleteLabel.fadeLength = 8.0;
        self.percentCompleteLabel.trailingBuffer = 10.0;
        
        [self.blurView.contentView addSubview:self.percentCompleteLabel];
    }
    
    /*if (!self.progressBar) {
        self.progressBar = [[MBCircularProgressBarView alloc] initWithFrame:CGRectZero];
        
        self.progressBar.value = 0.0;
        self.progressBar.maxValue = 100.0;
        self.progressBar.showUnitString = NO;
        self.progressBar.showValueString = NO;
        self.progressBar.progressCapType = kCGLineCapRound;
        self.progressBar.emptyCapType = kCGLineCapRound;
        self.progressBar.progressLineWidth = 1.5;
        self.progressBar.progressColor = [UIColor darkGrayColor];
        self.progressBar.progressStrokeColor = [UIColor darkGrayColor];
        self.progressBar.emptyLineColor = [UIColor lightGrayColor];
        self.progressBar.backgroundColor = [UIColor clearColor];
        
        self.progressBar.hidden = YES;
        
        [self.contentView addSubview:self.progressBar];
    }*/
    
    if (!self.notificationView) {
        self.notificationView = [[UIView alloc] initWithFrame:CGRectZero];
        self.notificationView.hidden = YES;
        
        [self.blurView.contentView insertSubview:self.notificationView atIndex:0];
    }
    
    // Reset text colours if needed
    self.displayNameLabel.textColor = [UIColor blackColor];
    self.displayNameLabel.textAlignment = NSTextAlignmentLeft;
    self.displayNameLabel.labelize = NO;
    
    self.bundleIdentifierLabel.textColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    self.timeRemainingLabel.textColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    
    // Reset hidden state if needed
    self.icon.hidden = NO;
    self.bundleIdentifierLabel.hidden = NO;
    self.timeRemainingLabel.hidden = NO;
    self.percentCompleteLabel.hidden = YES;
    //self.progressBar.hidden = YES;
    
    self.contentView.clipsToBounds = YES;
    self.contentView.layer.cornerRadius = 5;
    self.notificationView.layer.cornerRadius = 5;
    self.notificationView.clipsToBounds = YES;
    
    self.layer.shadowOpacity = 0.0;
    self.layer.shadowRadius = 10.0;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 27);
}

- (void)configureWithApplication:(RPVApplication*)application fallbackDisplayName:(NSString*)fallback andExpiryDate:(NSDate*)expiryDate {
    [self _setupUIIfNecessary];
    
    if (!application) {
        self.expiryDate = nil;
        self.bundleIdentifier = @"";
        
        // No application to display
        self.displayNameLabel.textColor = [UIColor whiteColor];
        self.displayNameLabel.textAlignment = NSTextAlignmentCenter;
        self.displayNameLabel.labelize = YES;
        
        // Set hidden state
        self.icon.hidden = YES;
        self.bundleIdentifierLabel.hidden = YES;
        self.timeRemainingLabel.hidden = YES;
        self.percentCompleteLabel.hidden = YES;
        //self.progressBar.hidden = YES;
        
        self.contentView.backgroundColor = [UIColor clearColor];
        
        self.noApplicationsInThisSection = YES;
        
        self.displayNameLabel.text = fallback;
        self.bundleIdentifierLabel.text = @"";
        self.timeRemainingLabel.text = @"";
    } else {
        self.expiryDate = expiryDate;
        
        self.bundleIdentifier = [application bundleIdentifier];
        self.noApplicationsInThisSection = NO;
        
        self.contentView.backgroundColor = [UIColor clearColor];
        
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            UIImage *icon = [application applicationIcon];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                self.icon.image = icon;
            });
        });
        
        self.displayNameLabel.text = [application applicationName];
        self.bundleIdentifierLabel.text = [application bundleIdentifier];
        
        self.timeRemainingLabel.text = [RPVResources getFormattedTimeRemainingForExpirationDate:self.expiryDate];
    }
    
    // Make sure MarqueeLabel is working as expected at all times.
    [self.displayNameLabel restartLabel];
    [self.bundleIdentifierLabel restartLabel];
    [self.timeRemainingLabel restartLabel];
    [self.percentCompleteLabel restartLabel];
}

- (void)flashNotificationSuccess {
    UIColor *successColour = [UIColor colorWithRed:119.0/255.0 green:207.0/255.0 blue:99.0/255.0 alpha:0.5];
    [self _flashNotificationWithColour:successColour];
}

- (void)flashNotificationFailure {
    UIColor *colour = [UIColor colorWithRed:207.0/255.0 green:99.0/255.0 blue:99.0/255.0 alpha:0.5];
    [self _flashNotificationWithColour:colour];
}

- (void)_flashNotificationWithColour:(UIColor*)colour {
    // If we're backgrounded, no need to flash else we get a bug.
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^(){
        self.notificationView.backgroundColor = colour;
        self.notificationView.alpha = 0.0;
        self.notificationView.hidden = NO;
        
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.notificationView.alpha = 1.0;
        } completion:^(BOOL finished) {
            if (finished) {
                [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    self.notificationView.alpha = 0.0;
                } completion:^(BOOL finished) {
                    if (finished) {
                        self.notificationView.hidden = YES;
                        self.notificationView.backgroundColor = [UIColor clearColor];
                    }
                }];
            }
        }];
    });
}

@end
