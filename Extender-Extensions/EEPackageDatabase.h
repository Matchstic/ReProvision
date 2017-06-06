//
//  EEPackageDatabase.h
//  Extender Installer
//
//  Created by Matt Clarke on 20/04/2017.
//
//  Manages the on-disk unsigned IPAs for local provisioned applications.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define EXTENDER_DOCUMENTS @"/var/mobile/Documents/Extender"

@class EEPackage;

@interface EEPackageDatabase : NSObject {
    NSDictionary *_packages;
    dispatch_queue_t _queue;
    NSMutableArray *_installQueue;
    NSArray *_teamIDApplications;
    UIBackgroundTaskIdentifier _currentBgTask;
    int _currentCycleCount;
    BOOL _isRevoking;
    NSMutableArray *_currentInstallQueue;
    
    BOOL _isLocked;
    BOOL _isLockedTaskQueued;
    int _notifyTokenForDidChangeDisplayStatus;
}

+ (instancetype)sharedInstance;

- (NSArray *)retrieveAllTeamIDApplications;
- (void)rebuildDatabase;
- (EEPackage*)packageForIdentifier:(NSString*)bundleIdentifier;
- (NSArray*)allPackages;

- (void)errorDidOccur:(NSString*)message;

- (void)resignApplicationsIfNecessaryWithTaskID:(UIBackgroundTaskIdentifier)bgTask andCheckExpiry:(BOOL)check;
- (void)installPackageAtURL:(NSURL*)url withManifest:(NSDictionary*)manifest;


@end
