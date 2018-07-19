//
//  RPVInstalledTableViewCell.h
//  iOS
//
//  Created by Matt Clarke on 03/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RPVInstalledTableViewCell : UITableViewCell

- (void)configureWithApplication:(id)application fallbackDisplayName:(NSString*)fallback andExpiryDate:(NSDate*)date;

- (void)flashNotificationSuccess;
- (void)flashNotificationFailure;

@end
