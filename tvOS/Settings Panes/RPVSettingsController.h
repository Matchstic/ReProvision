//
//  EESettingsController.h
//  Extender Installer
//
//  Created by Matt Clarke on 26/04/2017.
//
//

#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>

@interface RPVSettingsController : PSListController {
    NSArray *_loggedInAppleSpecifiers;
    NSArray *_loggedOutAppleSpecifiers;
    PSSpecifier *_loggedInSpec;
    BOOL _hasCachedUser;
}

@end
