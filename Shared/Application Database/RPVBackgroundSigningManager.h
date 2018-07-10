//
//  RPVBackgroundSigningManager.h
//  iOS
//
//  Created by Matt Clarke on 26/03/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RPVApplicationSigning.h"

@interface RPVBackgroundSigningManager : NSObject <RPVApplicationSigningProtocol>

+ (instancetype)sharedInstance;
- (void)attemptBackgroundSigningIfNecessary:(void (^)(void))completionHandler;

/**
 Checks if any applications need re-signing for the saved threshold.
 */
- (BOOL)anyApplicationsNeedingResigning;

@end
