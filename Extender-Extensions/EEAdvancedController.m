//
//  EEAdvancedController.m
//  Extender Installer
//
//  Created by Matt Clarke on 05/05/2017.
//
//

#import "EEAdvancedController.h"

@interface EEAdvancedController ()

@end

@implementation EEAdvancedController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[self navigationItem] setTitle:@"Advanced"];
}

-(id)specifiers {
    if (_specifiers == nil) {
        NSMutableArray *testingSpecs = [NSMutableArray array];
        
        // Create specifiers!
        [testingSpecs addObjectsFromArray:[self _signingSpecifiers]];
        [testingSpecs addObjectsFromArray:[self _errorHandlingSpecifiers]];
        
        _specifiers = testingSpecs;
    }
    
    return _specifiers;
}

- (NSArray*)_signingSpecifiers {
    NSMutableArray *array = [NSMutableArray array];
    
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Re-signing"];
    [group setProperty:@"Set how often checks are made for if any applications are in need of re-signing." forKey:@"footerText"];
    [array addObject:group];
    
    PSSpecifier *resign = [PSSpecifier preferenceSpecifierNamed:@"Re-sign in Low Power Mode" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    [resign setProperty:@"resignInLowPowerMode" forKey:@"key"];
    [resign setProperty:@0 forKey:@"default"];
    
    [array addObject:resign];
    
    // TODO: This needs to be hooked up in-code.
    PSSpecifier *threshold = [PSSpecifier preferenceSpecifierNamed:@"Check Expiry Times:" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:nil];
    [threshold setProperty:@NO forKey:@"enabled"];
    [threshold setProperty:@2 forKey:@"default"];
    threshold.values = [NSArray arrayWithObjects:@1, @2, @3, @4, @5, @6, nil];
    threshold.titleDictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Every 1 Hour", @"Every 2 Hours", @"Every 6 Hours", @"Every 12 Hours", @"Every 24 Hours", @"Every Other Day", nil] forKeys:threshold.values];
    threshold.shortTitleDictionary = threshold.titleDictionary;
    [threshold setProperty:@"checkTimeForResigning" forKey:@"key"];
    
    [array addObject:threshold];
    
    return array;
}

- (NSArray*)_errorHandlingSpecifiers {
    NSMutableArray *array = [NSMutableArray array];
    
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Error Handling"];
    [group setProperty:@"Some errors may be resolved automatically by revoking any existing certificates." forKey:@"footerText"];
    [array addObject:group];
    
    // TODO: Needs to be hooked up in-code
    PSSpecifier *resign = [PSSpecifier preferenceSpecifierNamed:@"Auto-Revoke Certificates" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    [resign setProperty:@"autoRevokeCertificates" forKey:@"key"];
    [resign setProperty:@NO forKey:@"enabled"];
    [resign setProperty:@0 forKey:@"default"];
    
    [array addObject:resign];
    
    return array;
}

- (id)readPreferenceValue:(PSSpecifier*)value {
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:[value propertyForKey:@"key"]];
    
    if (!val) {
        // Defaults.
        
        NSString *key = [value propertyForKey:@"key"];
        
        if ([key isEqualToString:@"resignInLowPowerMode"]) {
            return [NSNumber numberWithBool:NO];
        } else if ([key isEqualToString:@"checkTimeForResigning"]) {
            return [NSNumber numberWithInt:2];
        }else if ([key isEqualToString:@"autoRevokeCertificates"]) {
            return [NSNumber numberWithBool:NO];
        }
        
        return nil;
    } else {
        return val;
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:[specifier propertyForKey:@"key"]];
}

@end
