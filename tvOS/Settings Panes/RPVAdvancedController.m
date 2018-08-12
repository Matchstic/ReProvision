//
//  EEAdvancedController.m
//  Extender Installer
//
//  Created by Matt Clarke on 05/05/2017.
//
//

#import "RPVAdvancedController.h"
#import "RPVResources.h"

#include <notify.h>

@interface RPVAdvancedController ()
@property (nonatomic, readwrite) int daemonNotificationToken;
@end

@implementation RPVAdvancedController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[self navigationItem] setTitle:@"Advanced"];
    
    // Register token for daemon notifications.
    int status = notify_register_check("com.matchstic.reprovision.ios/debugStartBackgroundSign", &_daemonNotificationToken);
    if (status != NOTIFY_STATUS_OK) {
        fprintf(stderr, "registration failed (%u)\n", status);
        return;
    }
    
    self.view.backgroundColor = [UIColor clearColor];
    [(UITableView*)self.table setBackgroundColor:[UIColor clearColor]];
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
    
    PSSpecifier *resign = [PSSpecifier preferenceSpecifierNamed:@"Re-sign in Low Power Mode" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSListItemCell edit:nil];
    [resign setProperty:@"resignInLowPowerMode" forKey:@"key"];
    [resign setProperty:@0 forKey:@"default"];
    [resign setProperty:NSClassFromString(@"PSSubtitleDisclosureTableCell") forKey:@"cellClass"];
    
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
    
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Debugging Tools"];
    [group setProperty:@"Danger! Here be dragons..." forKey:@"footerText"];
    [array addObject:group];
    
    PSSpecifier *startBackgroundSign = [PSSpecifier preferenceSpecifierNamed:@"Initiate Background Signing" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    startBackgroundSign.buttonAction = @selector(startBackgroundSign:);
    
    [array addObject:startBackgroundSign];
    
    return array;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *represented = [self _specifierAtIndexPath:indexPath];
    
    // For fake switches
    if ([[represented propertyForKey:@"cellClass"] isEqual:NSClassFromString(@"PSSubtitleDisclosureTableCell")]) {
        static NSString *cellIdentifier = @"switch.cell";
        
        PSTableCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[PSTableCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier specifier:represented];
        } else {
            [cell setSpecifier:represented];
        }
        
        cell.textLabel.text = [represented name];
        
        // Setup end label.
        NSNumber *value = [self readPreferenceValue:represented];
        
        if (value.intValue == 0) {
            cell.detailTextLabel.text = [NSString localizedStringWithFormat:@"Off"];
        } else {
            cell.detailTextLabel.text = [NSString localizedStringWithFormat:@"On"];
        }
        
        return cell;
    } else {
        UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
        
        // Tint the cell if needed!
        if (represented.cellType == PSButtonCell)
            cell.textLabel.textColor = [UIApplication sharedApplication].delegate.window.tintColor;
        
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![self _handleFakeSwitchForIndexPath:indexPath])
        [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (BOOL)_handleFakeSwitchForIndexPath:(NSIndexPath*)indexPath {
    PSSpecifier *specifier = [self _specifierAtIndexPath:indexPath];
    
    if ([[specifier propertyForKey:@"cellClass"] isEqual:NSClassFromString(@"PSSubtitleDisclosureTableCell")]) {
        int currentValue = [[self readPreferenceValue:specifier] intValue];
        currentValue = currentValue == 0 ? 1 : 0;
        
        [self setPreferenceValue:[NSNumber numberWithBool:currentValue] specifier:specifier];
        [self reloadSpecifier:specifier];
        
        return YES;
    } else {
        return NO;
    }
}

- (PSSpecifier*)_specifierAtIndexPath:(NSIndexPath*)indexPath {
    // Find the type of cell this is.
    int section = (int)indexPath.section;
    int row = (int)indexPath.row;
    
    PSSpecifier *represented;
    NSArray *specifiers = [self specifiers];
    int currentSection = -1;
    int currentRow = 0;
    for (int i = 0; i < specifiers.count; i++) {
        PSSpecifier *spec = [specifiers objectAtIndex:i];
        
        // Update current sections
        if (spec.cellType == PSGroupCell) {
            currentSection++;
            currentRow = 0;
            continue;
        }
        
        // Check if this is the right specifier.
        if (currentRow == row && currentSection == section) {
            represented = spec;
            break;
        } else {
            currentRow++;
        }
    }
    
    return represented;
}

- (id)readPreferenceValue:(PSSpecifier*)value {
    NSString *key = [value propertyForKey:@"key"];
    id val = [RPVResources preferenceValueForKey:key];
    
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
    NSString *key = [specifier propertyForKey:@"key"];
    NSString *notification = specifier.properties[@"PostNotification"];
    
    [RPVResources setPreferenceValue:value forKey:key withNotification:notification];
}

/////////////////////////////////////////////////////////////////////////////////////
// Button actions
/////////////////////////////////////////////////////////////////////////////////////

- (void)startBackgroundSign:(id)sender {
    notify_set_state(self.daemonNotificationToken, 1);
    notify_post("com.matchstic.reprovision.ios/debugStartBackgroundSign");
}

@end
