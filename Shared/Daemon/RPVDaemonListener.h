//
//  RPVDaemonListener.h
//  iOS Daemon
//
//  Created by Matt Clarke on 05/07/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RPVDaemonProtocol.h"

@interface RPVDaemonListener : NSObject <NSXPCListenerDelegate, RPVDaemonProtocol> {
    int _lockstateToken;
    int _springboardBootToken;
    int _backboardBacklightChangedToken;
}

- (void)initialiseListener;

@end
