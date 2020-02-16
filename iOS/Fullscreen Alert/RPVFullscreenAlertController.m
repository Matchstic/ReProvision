//
//  RPVFullscreenAlertController.m
//  iOS
//
//  Created by Matt Clarke on 16/01/2020.
//  Copyright © 2020 Matt Clarke. All rights reserved.
//

#import "RPVFullscreenAlertController.h"
#import "RPVResources.h"

@interface RPVFullscreenAlertController ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIButton *dismissButton;
@end

@implementation RPVFullscreenAlertController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.text = @"Alert";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.font = [UIFont systemFontOfSize:34];
    
    [self.view addSubview:self.titleLabel];
    
    self.bodyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bodyLabel.text = @"ReProvision is no longer actively maintained.\n\nIf signing fails to work, it is recommended to use alternatives such as AltStore.";
    self.bodyLabel.textAlignment = NSTextAlignmentCenter;
    self.bodyLabel.numberOfLines = 0;
    
    [self.view addSubview:self.bodyLabel];
    
    self.imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"thatsallfolks.jpg"]];
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.layer.cornerRadius = 5;
    self.imageView.clipsToBounds = YES;
    
    [self.view addSubview:self.imageView];
    
    self.dismissButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.dismissButton setTitle:@"Dismiss" forState:UIControlStateNormal];
    [self.dismissButton addTarget:self action:@selector(onDismiss:) forControlEvents:UIControlEventTouchUpInside];
    [self.dismissButton sizeToFit];
    
    [self.view addSubview:self.dismissButton];
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        self.titleLabel.textColor = [UIColor labelColor];
        self.bodyLabel.textColor = [UIColor labelColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
        self.titleLabel.textColor = [UIColor blackColor];
        self.bodyLabel.textColor = [UIColor blackColor];
    }
    
    [self _layoutWithSize:[UIScreen mainScreen].bounds.size];
}

- (void)_layoutWithSize:(CGSize)size {
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    
    self.titleLabel.frame = CGRectMake(size.width * 0.1, statusBarFrame.size.height + 30, size.width * 0.8, 60);
    
    CGRect rect = [RPVResources boundedRectForFont:self.bodyLabel.font andText:self.bodyLabel.text width:size.width * 0.8];
    self.bodyLabel.frame = CGRectMake(size.width * 0.1, statusBarFrame.size.height + 120, size.width * 0.8, rect.size.height);
    
    CGFloat scale = (size.width * 0.8) / 950;
    self.imageView.frame = CGRectMake(size.width * 0.1, statusBarFrame.size.height + 120 + rect.size.height + 30, size.width * 0.8, 535 * scale);
    
    CGFloat safeAreaBottomInset = 34;
    
    self.dismissButton.frame = CGRectMake(size.width * 0.1, self.view.frame.size.height - self.dismissButton.frame.size.height - safeAreaBottomInset, size.width * 0.8, self.dismissButton.frame.size.height);
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [self _layoutWithSize:size];
}

- (void)onDismiss:(id)sender {
    self.onDismiss();
}

@end
