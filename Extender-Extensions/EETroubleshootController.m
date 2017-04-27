//
//  EETroubleshootController.m
//  Extender Installer
//
//  Created by Matt Clarke on 27/04/2017.
//
//

#import "EETroubleshootController.h"
#import "EEMultipleLineCell.h"

@interface EETroubleshootController ()

@end

@implementation EETroubleshootController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [[self navigationItem] setTitle:@"Troubleshooting"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Specifiers.

-(id)specifiers {
    if (_specifiers == nil) {
        NSMutableArray *testingSpecs = [NSMutableArray array];
        
        // Create specifiers!
        [testingSpecs addObjectsFromArray:[self _developmentCSRError]];
        
        _specifiers = testingSpecs;
    }
    
    return _specifiers;
}

- (NSArray*)_developmentCSRError {
    NSMutableArray *array = [NSMutableArray array];
    
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@""];
    [array addObject:group];
    
    PSSpecifier *title = [PSSpecifier preferenceSpecifierNamed:@"ios/submitDevelopmentCSR =7460" target:nil set:nil get:nil detail:nil cell:PSTitleValueCell edit:nil];
    [array addObject:title];
    
    NSString *info = @"This error usually occurs when running Extender on multiple devices with the same Apple ID.\n\nTo resolve, you can sign in on one device with a different Apple ID.\n\nNote: this issue is being looked into.";
    
    PSSpecifier *infoSpecifier = [PSSpecifier preferenceSpecifierNamed:info target:nil set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
    [[infoSpecifier userInfo] setObject:info forKey:@"name"];
    [infoSpecifier setProperty:[EEMultipleLineCell class] forKey:@"cellClass"];
    
    [array addObject:infoSpecifier];
    
    return array;
}

@end
