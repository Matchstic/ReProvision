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

#import <MBCircularProgressBarView.h>
#import <MarqueeLabel.h>

#define IS_IPAD UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad

@interface RPVInstalledCollectionViewCell ()

@property (nonatomic, readwrite) BOOL noApplicationsInThisSection;
@property (nonatomic, readwrite) BOOL isObserving;

@property (nonatomic, strong) NSDate *expiryDate;
@property (nonatomic, strong) NSTimer *expiryUpdateTimer;

// Content view.
@property (nonatomic, strong) UIImageView *smallIcon;

@property (nonatomic, strong) MarqueeLabel *displayNameLabel;
@property (nonatomic, strong) MarqueeLabel *bundleIdentifierLabel;
@property (nonatomic, strong) NSString *bundleIdentifier;

@property (nonatomic, strong) MarqueeLabel *timeRemainingLabel;

@property (nonatomic, strong) MarqueeLabel *percentCompleteLabel;
@property (nonatomic, strong) MBCircularProgressBarView *progressBar;

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
                self.progressBar.hidden = NO;
                
                self.timeRemainingLabel.hidden = YES;
            }
            
            // Update progess bar!
            [UIView animateWithDuration:percent == 0 ? 0.0 : 0.35 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                self.progressBar.value = percent;
                self.percentCompleteLabel.text = [NSString stringWithFormat:@"%d%% complete", percent];
            } completion:^(BOOL finished) {
                if (finished && percent == 100) {
                    self.percentCompleteLabel.hidden = YES;
                    self.progressBar.hidden = YES;
                    
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
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (!self.noApplicationsInThisSection) {
        CGFloat xInset = 10;
        CGFloat yInset = 10;
        
        self.smallIcon.frame = CGRectMake(xInset, yInset, IS_IPAD ? 45 : 30, IS_IPAD ? 45 : 30);
        yInset += self.smallIcon.frame.size.height + 10;
        
        self.displayNameLabel.frame = CGRectMake(xInset, yInset, self.contentView.frame.size.width - (xInset*2), IS_IPAD ? 27 : 18);
        
        yInset += self.displayNameLabel.frame.size.height;
        
        self.bundleIdentifierLabel.frame = CGRectMake(xInset, yInset, self.contentView.frame.size.width - (xInset*2), IS_IPAD ? 22.5 : 15);
        
        // Time remaining.
        self.timeRemainingLabel.frame = CGRectMake(xInset, self.contentView.frame.size.height - (IS_IPAD ? 33 : 28), self.contentView.frame.size.width - (xInset*2), 20);
        
        // Percent of signing.
        self.progressBar.frame = CGRectMake(xInset, self.contentView.frame.size.height - (IS_IPAD ? 33 : 28), 20, 20);
        self.percentCompleteLabel.frame = CGRectMake(xInset + self.progressBar.frame.size.width + 7, self.contentView.frame.size.height - (IS_IPAD ? 33 : 28), self.contentView.frame.size.width - (xInset*2) - self.progressBar.frame.size.width - 7, 20);
        
        self.notificationView.frame = self.contentView.bounds;
    } else {
        self.displayNameLabel.frame = self.contentView.bounds;
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    // Clear anything in the cell.
}

- (void)_setupUIIfNecessary {
    if (!self.isObserving) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_onSigningStatusUpdate:) name:@"com.matchstic.reprovision/signingUpdate" object:nil];
    }
    
    if (!self.smallIcon) {
        self.smallIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
        
        [self.contentView addSubview:self.smallIcon];
    }
    
    if (!self.displayNameLabel) {
        self.displayNameLabel = [[MarqueeLabel alloc] initWithFrame:CGRectZero];
        
        self.displayNameLabel.font = [UIFont systemFontOfSize:IS_IPAD ? 20 : 16 weight:UIFontWeightBold];
        self.displayNameLabel.text = @"DISPLAY_NAME";
        self.displayNameLabel.numberOfLines = 0;
        
        // MarqueeLabel specific
        self.displayNameLabel.fadeLength = 8.0;
        self.displayNameLabel.trailingBuffer = 10.0;
        
        [self.contentView addSubview:self.displayNameLabel];
    }
    
    if (!self.bundleIdentifierLabel) {
        self.bundleIdentifierLabel = [[MarqueeLabel alloc] initWithFrame:CGRectZero];
        
        self.bundleIdentifierLabel.text = @"BUNDLE_IDENTIFIER";
        self.bundleIdentifierLabel.font = [UIFont systemFontOfSize:IS_IPAD ? 12.5 : 11 weight:UIFontWeightRegular];
        
        // MarqueeLabel specific
        self.bundleIdentifierLabel.fadeLength = 8.0;
        self.bundleIdentifierLabel.trailingBuffer = 10.0;
        
        [self.contentView addSubview:self.bundleIdentifierLabel];
    }
    
    if (!self.timeRemainingLabel) {
        self.timeRemainingLabel = [[MarqueeLabel alloc] initWithFrame:CGRectZero];
        
        self.timeRemainingLabel.text = @"TIME_REMAINING";
        self.timeRemainingLabel.font = [UIFont systemFontOfSize:IS_IPAD ? 14 : 12 weight:UIFontWeightMedium];
        
        // MarqueeLabel specific
        self.timeRemainingLabel.fadeLength = 8.0;
        self.timeRemainingLabel.trailingBuffer = 10.0;
        
        [self.contentView addSubview:self.timeRemainingLabel];
    }
    
    if (!self.percentCompleteLabel) {
        self.percentCompleteLabel = [[MarqueeLabel alloc] initWithFrame:CGRectZero];
        
        self.percentCompleteLabel.text = @"0% complete";
        self.percentCompleteLabel.font = [UIFont systemFontOfSize:IS_IPAD ? 14 : 12 weight:UIFontWeightMedium];
        self.percentCompleteLabel.hidden = YES;
        self.percentCompleteLabel.textColor = [UIColor darkGrayColor];
        
        // MarqueeLabel specific
        self.percentCompleteLabel.fadeLength = 8.0;
        self.percentCompleteLabel.trailingBuffer = 10.0;
        
        [self.contentView addSubview:self.percentCompleteLabel];
    }
    
    if (!self.progressBar) {
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
    }
    
    if (!self.notificationView) {
        self.notificationView = [[UIView alloc] initWithFrame:CGRectZero];
        self.notificationView.hidden = YES;
        
        [self.contentView insertSubview:self.notificationView atIndex:0];
    }
    
    // Reset text colours if needed
    self.displayNameLabel.textColor = [UIColor blackColor];
    self.displayNameLabel.font = [UIFont systemFontOfSize:IS_IPAD ? 20 : 16 weight:UIFontWeightBold];
    self.displayNameLabel.textAlignment = NSTextAlignmentLeft;
    self.displayNameLabel.labelize = NO;
    
    self.bundleIdentifierLabel.textColor = [UIColor darkGrayColor];
    self.timeRemainingLabel.textColor = [UIColor grayColor];
    
    // Reset hidden state if needed
    self.smallIcon.hidden = NO;
    self.bundleIdentifierLabel.hidden = NO;
    self.timeRemainingLabel.hidden = NO;
    self.percentCompleteLabel.hidden = YES;
    self.progressBar.hidden = YES;
    
    self.contentView.clipsToBounds = YES;
    self.contentView.layer.cornerRadius = 12.5;
    self.notificationView.layer.cornerRadius = 12.5;
    self.notificationView.clipsToBounds = YES;
}

- (void)configureWithApplication:(RPVApplication*)application fallbackDisplayName:(NSString*)fallback andExpiryDate:(NSDate*)expiryDate {
    [self _setupUIIfNecessary];
    
    if (!application) {
        self.expiryDate = nil;
        
        // No application to display
        self.displayNameLabel.textColor = [UIColor whiteColor];
        self.displayNameLabel.font = [UIFont systemFontOfSize:IS_IPAD ? 20 : 16 weight:UIFontWeightRegular];
        self.displayNameLabel.textAlignment = NSTextAlignmentCenter;
        self.displayNameLabel.labelize = YES;
        
        // Set hidden state
        self.smallIcon.hidden = YES;
        self.bundleIdentifierLabel.hidden = YES;
        self.timeRemainingLabel.hidden = YES;
        self.percentCompleteLabel.hidden = YES;
        self.progressBar.hidden = YES;
        
        self.contentView.backgroundColor = [UIColor clearColor];
        
        self.noApplicationsInThisSection = YES;
        
        self.displayNameLabel.text = fallback;
        self.bundleIdentifierLabel.text = @"";
        self.timeRemainingLabel.text = @"";
    } else {
        self.expiryDate = expiryDate;
        
        self.bundleIdentifier = [application bundleIdentifier];
        self.noApplicationsInThisSection = NO;
        
        self.contentView.backgroundColor = [UIColor whiteColor];
        
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            UIImage *icon = [application applicationIcon];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                self.smallIcon.image = icon;
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
