//
//  RPVInstalledSectionHeaderView.h
//  
//
//  Created by Matt Clarke on 09/01/2018.
//

#import <UIKit/UIKit.h>

@protocol RPVInstalledSectionHeaderDelegate <NSObject>

- (void)didRecieveHeaderButtonInputWithSection:(NSInteger)section;
- (BOOL)isButtonEnabledForSection:(NSInteger)section;

@end

@interface RPVInstalledSectionHeaderViewController : UIViewController

@property (nonatomic, readwrite) BOOL invertColours;

- (void)configureWithTitle:(NSString*)title buttonLabel:(NSString*)buttonLabel section:(NSInteger)section andDelegate:(id<RPVInstalledSectionHeaderDelegate>)delegate;

- (void)requestNewButtonEnabledState;

@end
