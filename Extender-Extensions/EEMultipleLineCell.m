//
//  EEMultipleLineCell.m
//  Extender Installer
//
//  Created by Matt Clarke on 27/04/2017.
//
//

#import "EEMultipleLineCell.h"

@implementation EEMultipleLineCell

- (id)initWithSpecifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell" specifier:specifier];
    
    if (self) {
        _label = [[UILabel alloc] initWithFrame:[self frame]];
        
        _label.text = [specifier.userInfo objectForKey:@"name"];
        _label.textColor = [UIColor grayColor];
        _label.textAlignment = NSTextAlignmentLeft;
        _label.font = [UIFont systemFontOfSize:18];
        _label.numberOfLines = 0;
        
        [self.contentView addSubview:_label];
    }
    
    return self;
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

- (CGFloat)preferredHeightForWidth:(CGFloat)width {
    // Return a custom cell height.
    return [self boundedRectForFont:_label.font andText:_label.text width:width].size.height;
}

@end
