//
//  EETroubleshootController.m
//  Extender Installer
//
//  Created by Matt Clarke on 27/04/2017.
//
//

#import "EETroubleshootController.h"
#import "EEResources.h"

@interface EETroubleshootController ()

@end

#define REUSE @"troubleshoot.cell"

@implementation EETroubleshootController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [[self navigationItem] setTitle:@"Troubleshooting"];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:REUSE];
    self.tableView.allowsSelection = YES;
    
    [self _setupDataSauce];
    [self.tableView reloadData];
}

- (void)_setupDataSauce {
    // data sauce.
    NSMutableArray *items = [NSMutableArray array];
    
    // ios/submitDevelopmentCSR =7460
    
    NSMutableArray *submitDevelopmentCSR = [NSMutableArray array];
    [submitDevelopmentCSR addObject:@"ios/submitDevelopmentCSR =7460"];
    [submitDevelopmentCSR addObject:@"This error usually occurs when running Extender on multiple devices with the same Apple ID.\n\nOne possible solution is to revoke developer certificates, which can be done below."];
    [submitDevelopmentCSR addObject:@"Revoke Certificates"];
    
    [items addObject:submitDevelopmentCSR];
    
    NSMutableArray *dotAppInfoPlist = [NSMutableArray array];
    [dotAppInfoPlist addObject:@".app/Info.plist"];
    [dotAppInfoPlist addObject:@"This error may occur when Extender attempts to create an IPA for an application.\n\nTo resolve, simply try again another time."];
    
    [items addObject:dotAppInfoPlist];
    
    NSMutableArray *archive = [NSMutableArray array];
    [archive addObject:@"Could not extract archive"];
    [archive addObject:@"This error may occur when an IPA is signed, but not repackaged correctly.\n\nTo resolve, simply try again another time."];
    
    [items addObject:archive];
    
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
    
    // Also handle if a button.
    if (indexPath.row == 2) {
        cell.textLabel.textColor = [UIColor redColor];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
    } else {
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
    }
    
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
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSArray *split = [str componentsSeparatedByString:@"\n\n"];
        extra += (split.count - 1) * 20;
    }
    
    return [self boundedRectForFont:font andText:str width:self.tableView.contentSize.width].size.height + extra;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

// Selection.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == 2) {
        // This is a button.
        
        switch (indexPath.section) {
            case 0:
                [EEResources attemptToRevokeCertificateWithCallback:^(BOOL success) {}];
                break;
                
            default:
                break;
        }
    }
}

// XXX: As we are going to be presented by Preferences.framework, we have to implement a couple of shims.
- (void)setRootController:(id)controller {}
- (void)setParentController:(id)controller {}
- (void)setSpecifier:(id)specifier {}

@end
