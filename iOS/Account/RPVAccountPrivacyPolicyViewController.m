//
//  RPVAccountPrivacyPolicyViewController.m
//  iOS
//
//  Created by Matt Clarke on 07/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVAccountPrivacyPolicyViewController.h"

@interface RPVAccountPrivacyPolicyViewController ()

@end

@implementation RPVAccountPrivacyPolicyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero];
    
    NSString *document =  [[NSBundle mainBundle] pathForResource:@"privacy-policy" ofType:@"html"];
    NSURL *url = [NSURL fileURLWithPath:document];
    self.webView.navigationDelegate = self;
    [self.webView loadFileURL:url allowingReadAccessToURL:url];
    
    [self.view addSubview:self.webView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.webView.frame = self.view.bounds;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    [self.navigationController.navigationBar setShadowImage:nil];
}

// WKWebView navigation delegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [[self navigationItem] setTitle:self.webView.title];
}



@end
