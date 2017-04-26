//
//  EESettingsController.m
//  Extender Installer
//
//  Created by Matt Clarke on 26/04/2017.
//
//

#import "EESettingsController.h"
#import "EEResources.h"

@interface PSSpecifier (Private)
- (void)setButtonAction:(SEL)arg1;
@end

@implementation EESettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[self navigationItem] setTitle:@"Settings"];
}

-(id)specifiers {
    if (_specifiers == nil) {
        NSMutableArray *testingSpecs = [NSMutableArray array];
        
        // Create specifiers!
        [testingSpecs addObjectsFromArray:[self _appleIDSpecifiers]];
        [testingSpecs addObjectsFromArray:[self _alertSpecifiers]];
        
        _specifiers = testingSpecs;
    }
    
    return _specifiers;
}

- (NSArray*)_appleIDSpecifiers {
    NSMutableArray *loggedIn = [NSMutableArray array];
    NSMutableArray *loggedOut = [NSMutableArray array];
    
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Apple ID"];
    [loggedOut addObject:group];
    [loggedIn addObject:group];
    
    // Logged in
    
    NSString *title = [NSString stringWithFormat:@"Apple ID: %@", [EEResources username]];
    PSSpecifier *appleid = [PSSpecifier preferenceSpecifierNamed:title target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
    
    [loggedIn addObject:appleid];
    
    PSSpecifier *signout = [PSSpecifier preferenceSpecifierNamed:@"Sign Out" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    [signout setButtonAction:@selector(didClickSignOut:)];
    
    [loggedIn addObject:signout];
    
    // Logged out.
    
    PSSpecifier *signin = [PSSpecifier preferenceSpecifierNamed:@"Sign In" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    [signin setButtonAction:@selector(didClickSignIn:)];
    
    [loggedOut addObject:signin];
    
    _loggedInAppleSpecifiers = loggedIn;
    _loggedOutAppleSpecifiers = loggedOut;
    
    BOOL hasCachedUser = [EEResources username] != nil;
    return hasCachedUser ? _loggedInAppleSpecifiers : _loggedOutAppleSpecifiers;
}

- (NSArray*)_alertSpecifiers {
    NSMutableArray *array = [NSMutableArray array];
    
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Configuration"];
    [array addObject:group];
    
    PSSpecifier *showAlerts = [PSSpecifier preferenceSpecifierNamed:@"Show Alerts" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    [showAlerts setProperty:@"showAlerts" forKey:@"key"];
    
    [array addObject:showAlerts];
    
    PSSpecifier *showDebugAlerts = [PSSpecifier preferenceSpecifierNamed:@"Show Debug Alerts" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    [showDebugAlerts setProperty:@"showDebugAlerts" forKey:@"key"];
    
    [array addObject:showDebugAlerts];
    
    return array;
}

- (void)updateSpecifiersForAppleID {
    BOOL hasCachedUser = [EEResources username] != nil;
    
    if (hasCachedUser) {
        [self removeContiguousSpecifiers:_loggedOutAppleSpecifiers animated:YES];
        [self insertContiguousSpecifiers:_loggedInAppleSpecifiers atIndex:0];
    } else {
        [self removeContiguousSpecifiers:_loggedInAppleSpecifiers animated:YES];
        [self insertContiguousSpecifiers:_loggedOutAppleSpecifiers atIndex:0];
    }
}

- (void)didClickSignOut:(id)sender {
    [EEResources signOut];
    
    [self updateSpecifiersForAppleID];
}

- (void)didClickSignIn:(id)sender {
    [EEResources signInWithCallback:^(BOOL result) {
        [self updateSpecifiersForAppleID];
    }];
}

- (id)readPreferenceValue:(PSSpecifier*)value {
    if ([[value propertyForKey:@"key"] isEqualToString:@"showAlerts"]) {
        return [NSNumber numberWithBool:[EEResources shouldShowAlerts]];
    } else if ([[value propertyForKey:@"key"] isEqualToString:@"showDebugAlerts"]) {
        return [NSNumber numberWithBool:[EEResources shouldShowDebugAlerts]];
    }
    
    return nil;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    if ([[specifier propertyForKey:@"key"] isEqualToString:@"showAlerts"]) {
        
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:@"showAlerts"];
        
    } else if ([[specifier propertyForKey:@"key"] isEqualToString:@"showDebugAlerts"]) {
        
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:@"showDebugAlerts"];
        
    }
}

@end
