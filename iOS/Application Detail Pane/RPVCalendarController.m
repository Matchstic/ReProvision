//
//  RPVCalendarController.m
//  iOS
//
//  Created by Matt Clarke on 16/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVCalendarController.h"
#import "RPVCalendarCell.h"

@interface RPVCalendarController ()
@property (nonatomic, strong) NSDate *dateToDisplay;

@property (nonatomic, strong) NSMutableArray *cells;

@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@end

@implementation RPVCalendarController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (instancetype)initWithDate:(NSDate*)date {
    self = [super init];
    
    if (self) {
        self.dateToDisplay = date;
    }
    
    return self;
}

- (CGFloat)calendarHeight {
    return CELL_HEIGHT + 60;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:CGRectZero];
    self.view.backgroundColor = [UIColor clearColor];
    
    // Setup cells
    
    // Work out which cell is to be the selected cell.
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitDay|NSCalendarUnitWeekday fromDate:self.dateToDisplay];
    
    // Handle with locale specific changes for weekdayStart.
    int selected = (int)[components weekday] - (int)[NSCalendar currentCalendar].firstWeekday;
    if (selected < 0)
        selected = 7 - abs(selected);
    
    NSDate *startDate = [self.dateToDisplay dateByAddingTimeInterval:-60 * 60 * 24 * selected];
    
    self.cells = [@[] mutableCopy];
    // Create the cells and add to the UI.
    for (int i = 0; i < 7; i++) {
        RPVCalendarCell *cell = [[RPVCalendarCell alloc] initWithFrame:CGRectZero];
        
        [cell setDate:[startDate dateByAddingTimeInterval:60 * 60 * 24 * i]];
        [cell setSelected:i == selected];
        
        [self.view addSubview:cell];
        
        [self.cells addObject:cell];
    }
    
    // Date/time text
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"EEEEdMMMM" options:0 locale:[NSLocale currentLocale]];
    
    self.dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.dateLabel.text = [dateFormatter stringFromDate:self.dateToDisplay];
    self.dateLabel.textColor = [UIColor blackColor];
    self.dateLabel.textAlignment = NSTextAlignmentCenter;
    self.dateLabel.font = [UIFont systemFontOfSize:18];
    
    [self.view addSubview:self.dateLabel];
    
    // Check for 24hr time
    NSString *formatStringForHours = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:[NSLocale currentLocale]];
    
    NSRange containsA = [formatStringForHours rangeOfString:@"a"];
    BOOL hasAMPM = containsA.location != NSNotFound;
    
    if (hasAMPM)
        dateFormatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"hh:mm a" options:0 locale:[NSLocale currentLocale]];
    else
        dateFormatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"HH:mm" options:0 locale:[NSLocale currentLocale]];
    
    self.timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.timeLabel.text = [dateFormatter stringFromDate:self.dateToDisplay];
    self.timeLabel.textColor = [UIColor grayColor];
    self.timeLabel.textAlignment = NSTextAlignmentCenter;
    self.timeLabel.font = [UIFont systemFontOfSize:16];
    
    [self.view addSubview:self.timeLabel];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat inset = 10;
    CGFloat cellMargin = (self.view.frame.size.width - (CELL_WIDTH * 7) - inset*2.0)/8.0;
    NSLog(@"CellMargin: %f", cellMargin);
    for (int i = 0; i < self.cells.count; i++) {
        RPVCalendarCell *cell = [self.cells objectAtIndex:i];
        
        cell.frame = CGRectMake(inset + cellMargin * (i+1) + CELL_WIDTH*i, 0, CELL_WIDTH, CELL_HEIGHT);
    }
    
    self.dateLabel.frame = CGRectMake(inset, CELL_HEIGHT + 10, self.view.frame.size.width - inset*2, 20);
    self.timeLabel.frame = CGRectMake(inset, CELL_HEIGHT + 10 + 20 + 10, self.view.frame.size.width - inset*2, 20);
}

@end
