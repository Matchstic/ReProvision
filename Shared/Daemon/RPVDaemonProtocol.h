//
//  RPVDaemonProtocol.h
//  ReProvision
//
//  Created by Matt Clarke on 24/08/2019.
//  Copyright © 2019 Matt Clarke. All rights reserved.
//

@protocol RPVDaemonProtocol <NSObject>

- (void)applicationDidLaunch;
- (void)applicationDidFinishTask;

- (void)applicationRequestsDebuggingBackgroundSigning;
- (void)applicationRequestsPreferencesUpdate;

@end
