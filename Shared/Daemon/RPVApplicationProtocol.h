//
//  RPVApplicationProtocol.h
//  ReProvision
//
//  Created by Matt Clarke on 24/08/2019.
//  Copyright © 2019 Matt Clarke. All rights reserved.
//

@protocol RPVApplicationProtocol <NSObject>

- (void)daemonDidRequestNewBackgroundSigning;
- (void)daemonDidRequestCredentialsCheck;
- (void)daemonDidRequestQueuedNotification;

@end
