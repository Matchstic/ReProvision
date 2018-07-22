//
//  RPVCalendarCell.m
//  iOS
//
//  Created by Matt Clarke on 16/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVCalendarCell.h"

@interface RPVCalendarCell ()

@property (nonatomic, strong) UILabel *weekdaySymbolLabel;
@property (nonatomic, strong) UILabel *dayNumberLabel;
@property (nonatomic, strong) UIView *selectedDotView;

@end

@implementation RPVCalendarCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:CGRectMake(0, 0, CELL_WIDTH, CELL_HEIGHT)];
    
    if (self) {
        [self _loadSubviews];
    }
    
    return self;
}

- (void)_loadSubviews {
    self.weekdaySymbolLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CELL_WIDTH, 25)];
    self.weekdaySymbolLabel.text = @"X";
    self.weekdaySymbolLabel.textColor = [UIColor grayColor];
    self.weekdaySymbolLabel.textAlignment = NSTextAlignmentCenter;
    self.weekdaySymbolLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightLight];
    
    [self addSubview:self.weekdaySymbolLabel];
    
    self.dayNumberLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 25, CELL_WIDTH, CELL_WIDTH)];
    self.dayNumberLabel.text = @"00";
    self.dayNumberLabel.textColor = [UIColor blackColor];
    self.dayNumberLabel.textAlignment = NSTextAlignmentCenter;
    self.dayNumberLabel.font = [UIFont systemFontOfSize:20];
    
    [self addSubview:self.dayNumberLabel];
    
    self.selectedDotView = [[UIView alloc] initWithFrame:CGRectMake(0, 25, CELL_WIDTH, CELL_WIDTH)];
    self.selectedDotView.backgroundColor = [UIApplication sharedApplication].keyWindow.tintColor;
    self.selectedDotView.hidden = YES;
    self.selectedDotView.layer.cornerRadius = CELL_WIDTH/2.0;
    self.selectedDotView.clipsToBounds = YES;
    
    [self insertSubview:self.selectedDotView belowSubview:self.dayNumberLabel];
}

- (void)setSelected:(BOOL)selected {
    self.selectedDotView.hidden = !selected;
    self.dayNumberLabel.textColor = selected ? [UIColor whiteColor] : [UIColor blackColor];
}

- (void)setDate:(NSDate*)date {
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitDay|NSCalendarUnitWeekday fromDate:date];
    NSArray *dayLetters = [[NSCalendar currentCalendar] veryShortWeekdaySymbols];
    NSInteger dayNumber = [components day];
    
    self.dayNumberLabel.text = [NSString stringWithFormat:@"%ld", (long)dayNumber];
    self.weekdaySymbolLabel.text = [dayLetters objectAtIndex:[components weekday]-1];
}

@end
