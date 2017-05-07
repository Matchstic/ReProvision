//
//  EEAdvancedController.m
//  Extender Installer
//
//  Created by Matt Clarke on 05/05/2017.
//
//

#import "EEAdvancedController.h"
#import "EEResources.h"

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
    
    PSSpecifier *threshold = [PSSpecifier preferenceSpecifierNamed:@"Check Expiry Times:" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:NSClassFromString(@"PSListItemsController") cell:PSLinkListCell edit:nil];
    [threshold setProperty:@YES forKey:@"enabled"];
    [threshold setProperty:@2 forKey:@"default"];
    threshold.values = [NSArray arrayWithObjects:@1, @2, @6, @12, @24, @48, nil];
    threshold.titleDictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Every 1 Hour", @"Every 2 Hours", @"Every 6 Hours", @"Every 12 Hours", @"Every 24 Hours", @"Every Other Day", nil] forKeys:threshold.values];
    threshold.shortTitleDictionary = threshold.titleDictionary;
    [threshold setProperty:@"heartbeatTimerInterval" forKey:@"key"];
    [threshold setProperty:@"A longer time between checks uses less battery, but has more risk that applications won't be re-signed before a reboot." forKey:@"staticTextMessage"];
    
    [array addObject:threshold];
    
    return array;
}

- (NSArray*)_errorHandlingSpecifiers {
    NSMutableArray *array = [NSMutableArray array];
    
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Error Handling"];
    [group setProperty:@"Some errors may be resolved automatically by revoking any existing certificates. This is only a temporary workaround.\n\nIt is strongly NOT recommended to use this feature if you use Extender: Reloaded on multiple devices." forKey:@"footerText"];
    [array addObject:group];
    
    PSSpecifier *resign = [PSSpecifier preferenceSpecifierNamed:@"Auto-Revoke Certificates" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    [resign setProperty:@"shouldAutoRevokeIfNeeded" forKey:@"key"];
    [resign setProperty:@YES forKey:@"enabled"];
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
        } else if ([key isEqualToString:@"heartbeatTimerInterval"]) {
            return [NSNumber numberWithInt:2];
        } else if ([key isEqualToString:@"shouldAutoRevokeIfNeeded"]) {
            return [NSNumber numberWithBool:NO];
        }
        
        return nil;
    } else {
        return val;
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:[specifier propertyForKey:@"key"]];
    
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"heartbeatTimerInterval"]) {
        [EEResources reloadHeartbeatTimer];
    }
}

@end
