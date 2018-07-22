//
//  RPVInstalledViewController.h
//  iOS
//
//  Created by Matt Clarke on 03/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RPVInstalledSectionHeaderView.h"
#import "RPVApplicationSigning.h"

@interface RPVInstalledViewController : UIViewController <RPVInstalledSectionHeaderDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UITableViewDelegate, UITableViewDataSource, RPVApplicationSigningProtocol>

@end
