//
//  RPVInstalledCollectionSectionHeaderView.h
//  
//
//  Created by Matt Clarke on 09/01/2018.
//

#import <UIKit/UIKit.h>

@protocol RPVInstalledCollectionSectionHeaderDelegate <NSObject>

- (void)didRecieveHeaderButtonInputWithSection:(NSInteger)section;

@end

@interface RPVInstalledCollectionSectionHeaderView : UICollectionReusableView

- (void)configureWithTitle:(NSString*)title buttonLabel:(NSString*)buttonLabel section:(NSInteger)section andDelegate:(id<RPVInstalledCollectionSectionHeaderDelegate>)delegate;

@end
