//
//  EEPackagesCell.h
//  Extender Installer
//
//  Created by Matt Clarke on 14/04/2017.
//
//

#import <UIKit/UIKit.h>

@class LSApplicationProxy;

@interface EEPackagesCell : UITableViewCell {
    LSApplicationProxy *_proxy;
    NSCalendar *_calendar;
}

@property (nonatomic, strong) UIImageView *icon;
@property (nonatomic, strong) UILabel *localisedTitleLabel;
@property (nonatomic, strong) UILabel *bundleIdentifierLabel;
@property (nonatomic, strong) UILabel *lastSignedLabel;

- (void)setupWithProxy:(LSApplicationProxy*)proxy;

@end
