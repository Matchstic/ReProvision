//
//  RPVInstalledCollectionViewCell.m
//  iOS
//
//  Created by Matt Clarke on 09/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "RPVInstalledCollectionViewCell.h"

@interface RPVInstalledCollectionViewCell ()

@property (nonatomic, strong) UIView *highlightingView;

// Content view.
@property (nonatomic, strong) UIImageView *smallIcon;
@property (nonatomic, strong) UIImageView *largeIcon;

@end

@implementation RPVInstalledCollectionViewCell

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        // Corner radius
        self.layer.cornerRadius = 12.5;
        
        // Dropshadow
        self.layer.shadowRadius = 9;
        self.layer.shadowColor = [UIColor grayColor].CGColor;
        self.layer.shadowOpacity = 0.2;
        self.layer.shadowOffset = CGSizeZero;
        
        // Highlighting view needs to always be on top to correctly darken content.
        self.highlightingView = [[UIView alloc] initWithFrame:CGRectZero];
        self.highlightingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.1];
        self.highlightingView.hidden = YES;
        self.highlightingView.layer.cornerRadius = self.layer.cornerRadius;
        
        [self addSubview:self.highlightingView];
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.highlightingView.frame = self.bounds;
}

- (void)setHighlighted:(BOOL)highlighted {
    self.highlightingView.hidden = !highlighted;
    [self setNeedsDisplay];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    // Clear anything in the cell.
}

@end
