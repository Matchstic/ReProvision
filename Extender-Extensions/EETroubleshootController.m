//
//  EETroubleshootController.m
//  Extender Installer
//
//  Created by Matt Clarke on 27/04/2017.
//
//

#import "EETroubleshootController.h"
#import "EEMultipleLineCell.h"

@interface EETroubleshootController ()

@end

#define REUSE @"troubleshoot.cell"

@implementation EETroubleshootController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [[self navigationItem] setTitle:@"Troubleshooting"];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:REUSE];
    self.tableView.allowsSelection = NO;
    
    [self _setupDataSauce];
    [self.tableView reloadData];
}

- (void)_setupDataSauce {
    // data sauce.
    NSMutableArray *items = [NSMutableArray array];
    
    // ios/submitDevelopmentCSR =7460
    
    NSMutableArray *submitDevelopmentCSR = [NSMutableArray array];
    [submitDevelopmentCSR addObject:@"ios/submitDevelopmentCSR =7460"];
    [submitDevelopmentCSR addObject:@"This error usually occurs when running Extender on multiple devices with the same Apple ID.\n\nTo resolve, you can sign in on one device with a different Apple ID.\n\nNote: this issue is being looked into to remove this need for another Apple ID."];
    
    [items addObject:submitDevelopmentCSR];
    
    NSMutableArray *dotAppInfoPlist = [NSMutableArray array];
    [dotAppInfoPlist addObject:@".app/Info.plist"];
    [dotAppInfoPlist addObject:@"This error may occur when Extender attempts to create an IPA for an application.\n\nTo resolve, simply try again another time."];
    
    [items addObject:dotAppInfoPlist];
    
    _dataSauce = items;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:UITableViewStyleGrouped];
    
    if (self) {
        
    }
    
    return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// table view delegate.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _dataSauce.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[_dataSauce objectAtIndex:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:REUSE forIndexPath:indexPath];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:REUSE];
    }
    
    NSArray *items = [_dataSauce objectAtIndex:indexPath.section];
    NSString *str = [items objectAtIndex:indexPath.row];
    
    BOOL isBold = indexPath.row == 0;
    
    cell.textLabel.text = str;
    cell.textLabel.textColor = isBold ? [UIColor darkTextColor] : [UIColor grayColor];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

-(CGRect)boundedRectForFont:(UIFont*)font andText:(id)text width:(CGFloat)width {
    if (!text || !font) {
        return CGRectZero;
    }
    
    if (![text isKindOfClass:[NSAttributedString class]]) {
        NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName:font}];
        CGRect rect = [attributedText boundingRectWithSize:(CGSize){width, CGFLOAT_MAX}
                                                   options:NSStringDrawingUsesLineFragmentOrigin
                                                   context:nil];
        return rect;
    } else {
        return [(NSAttributedString*)text boundingRectWithSize:(CGSize){width, CGFLOAT_MAX}
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                       context:nil];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIFont *font = [UIFont systemFontOfSize:18];
    NSArray *items = [_dataSauce objectAtIndex:indexPath.section];
    NSString *str = [items objectAtIndex:indexPath.row];
    
    CGFloat extra = 24;
    
    // We also need to add an additional 20pt for each instance of "\n\n" in the string.
    NSArray *split = [str componentsSeparatedByString:@"\n\n"];
    extra += (split.count - 1) * 20;
    
    return [self boundedRectForFont:font andText:str width:self.tableView.contentSize.width].size.height + extra;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

// XXX: As we are going to be presented by Preferences.framework, we have to implement a couple of shims.
- (void)setRootController:(id)controller {}
- (void)setParentController:(id)controller {}
- (void)setSpecifier:(id)specifier {}

@end
