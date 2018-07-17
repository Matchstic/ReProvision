//
//  RPVCalendarCell.h
//  iOS
//
//  Created by Matt Clarke on 16/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>

#define CELL_WIDTH 40
#define CELL_HEIGHT 65

@interface RPVCalendarCell : UIView

- (void)setSelected:(BOOL)selected;
- (void)setDate:(NSDate*)date;

@end
