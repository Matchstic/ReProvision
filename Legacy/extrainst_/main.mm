//
//  main.m
//  Extender Installer
//
//  Created by Matt Clarke on 13/04/2017.
//  Copyright (c) 2017 Matchstic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SSZipArchive/SSZipArchive.h"
#import <objc/runtime.h>
#include <spawn.h>

#import "SAMKeychain/SAMKeychain.h"

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)uninstallApplication:(NSString*)arg1 withOptions:(NSDictionary*)arg2;
- (BOOL)applicationIsInstalled:(NSString*)arg1;
@end

@interface LSApplicationProxy : NSObject
+ (instancetype)applicationProxyForIdentifier:(NSString*)arg1;
- (BOOL)isSystemOrInternalApp;
@end

void cleanup();

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *extenderEntitlements = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?> \
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"> \
<plist version=\"1.0\"> \
<dict> \
<key>com.apple.developer.team-identifier</key> \
<string>AAAAAAAAAA</string> \
 \
<key>application-identifier</key> \
<string>AAAAAAAAAA.com.cydia.Extender</string> \
 \
<key>com.apple.security.application-groups</key> \
<array> \
<string>group.com.cydia.Extender</string> \
</array> \
 \
<key>com.apple.developer.networking.networkextension</key> \
<array> \
<string>packet-tunnel-provider</string> \
</array> \
\
<key>keychain-access-groups</key> \
<array> \
<string>AAAAAAAAAA.com.cydia.Extender</string> \
</array> \
 \
<key>com.apple.private.mobileinstall.allowedSPI</key> \
<array> \
<string>Lookup</string> \
<string>Install</string> \
<string>Browse</string> \
<string>Uninstall</string> \
<string>LookupForLaunchServices</string> \
<string>InstallForLaunchServices</string> \
<string>BrowseForLaunchServices</string> \
<string>UninstallForLaunchServices</string> \
<string>InstallLocalProvisioned</string> \
</array>  \
<key>com.apple.lsapplicationworkspace.rebuildappdatabases</key>  \
<true/>  \
  \
<key>com.apple.private.MobileContainerManager.allowed</key>  \
<true/>  \
<key>platform-application</key> \
<true/> \
<key>com.apple.private.security.no-container</key> \
<true/> \
<key>com.apple.private.skip-library-validation</key> \
<true/> \
</dict> \
</plist>";

static NSString *vpnEntitlements = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?> \
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"> \
<plist version=\"1.0\"> \
<dict> \
<key>com.apple.developer.team-identifier</key> \
<string>AAAAAAAAAA</string> \
\
<key>application-identifier</key> \
<string>AAAAAAAAAA.com.cydia.Extender.VPN</string> \
 \
<key>com.apple.security.application-groups</key> \
<array> \
<string>group.com.cydia.Extender</string> \
</array> \
\
<key>com.apple.developer.networking.networkextension</key> \
<array> \
<string>packet-tunnel-provider</string> \
</array> \
</dict> \
</plist>";

void xlog(NSString *string) {
    printf("%s\n", [string UTF8String]);
}

static int run_system(const char *args[]) {
    pid_t pid;
    int stat;
    posix_spawn(&pid, args[0], NULL, NULL, (char **) args, NULL);
    waitpid(pid, &stat, 0);
    return stat;
}

void runPreflightChecks() {
    // We will check if:
    // a) The user has enough space for installation (at least 30MB).
    // b) If any existing version of Cydia Extender (com.saurik.Extender) is installed. (We will do this when installation is known to be ready).
    
    xlog(@"Running pre-installation checks.");
    
    // If Extender is already installed, logically there is enough space to overwrite it.
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/Extender.app"]) {
        // Installed size: 9434519 (~10MB: 10000000).
        // No need to worry about download size, as we download to the user partition.
        NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/Applications" error:nil];
    
        if (dictionary) {
            NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
            unsigned long totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
        
            if (totalFreeSpace < 10000000) {
                xlog(@"Not enough space free to install Cydia Extender. Aborting.");
                xlog(@"*******************************************");
                xlog(@"Please remove some tweaks and/or themes, or utilise stashing.");
                xlog(@"*******************************************");
                
                exit(1);
            }
        } else {
            xlog(@"Failed to read attributes of /Applications. Aborting.");
            exit(1);
        }
    }
}

void downloadImpactor() {
    [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/mobile/tmp/Extender/" withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *stringURL = @"https://cydia.saurik.com/api/latest/2";
    NSURL  *url = [NSURL URLWithString:stringURL];
    NSData *urlData = [NSData dataWithContentsOfURL:url];
    if (urlData) {
        NSString  *filePath = @"/var/mobile/tmp/Extender/Impactor.zip";
        [urlData writeToFile:filePath atomically:YES];
    } else {
        xlog(@"Failed to download Cydia Extender. Aborting.");
        xlog(@"*******************************************");
        xlog(@"Try installing again another time.");
        xlog(@"*******************************************");
        
        cleanup();
        
        exit(1);
    }
    
    xlog(@"Downloaded.");
}

void extractExtender() {
    [SSZipArchive unzipFileAtPath:@"/var/mobile/tmp/Extender/Impactor.zip" toDestination:@"/var/mobile/tmp/Extender/Impactor/"];
    
    [SSZipArchive unzipFileAtPath:@"/var/mobile/tmp/Extender/Impactor/Impactor.dat" toDestination:@"/var/mobile/tmp/Extender/Impactor/Dat/"];
    
    // We will now pull out the ipa, and move it somewhere a little more sane.
    [[NSFileManager defaultManager] copyItemAtPath:@"/var/mobile/tmp/Extender/Impactor/Dat/extender.ipa" toPath:@"/var/mobile/tmp/Extender/extender.ipa" error:nil];
    
    [SSZipArchive unzipFileAtPath:@"/var/mobile/tmp/Extender/extender.ipa" toDestination:@"/var/mobile/tmp/Extender/extracted/"];
    
    xlog(@"Extracted to /var/mobile/tmp/Extender/extracted/");
    
    // Cleanup
    [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/tmp/Extender/Impactor.zip" error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/tmp/Extender/Impactor/" error:nil];
}

void insertTeamIDAndSaveEntitlements(NSString *teamid) {
    vpnEntitlements = [vpnEntitlements stringByReplacingOccurrencesOfString:@"AAAAAAAAAA" withString:teamid];
    extenderEntitlements = [extenderEntitlements stringByReplacingOccurrencesOfString:@"AAAAAAAAAA" withString:teamid];
    
    // Write plists.
    NSData *vpnData = [NSData dataWithBytes:[vpnEntitlements UTF8String] length:vpnEntitlements.length];
    if (vpnData) {
        NSString *filePath = @"/var/mobile/tmp/Extender/vpn.entitlements";
        [vpnData writeToFile:filePath atomically:YES];
    }
    
    NSData *extenderData = [NSData dataWithBytes:[extenderEntitlements UTF8String] length:extenderEntitlements.length];
    if (extenderData) {
        NSString *filePath = @"/var/mobile/tmp/Extender/extender.entitlements";
        [extenderData writeToFile:filePath atomically:YES];
    }
    
    xlog(@"Wrote entitlements to disk.");
}

void modifyInfoPlist() {
    // We need to add background modes to Extender for auto-signing.
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/tmp/Extender/extracted/Payload/Extender.app/Info.plist"];
    
    NSArray *modes = @[@"continuous", @"remote-notification", @"audio", @"fetch"];
    [dict setObject:modes forKey:@"UIBackgroundModes"];
    
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"SBAppUsesLocalNotifications"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"SBLaunchSuspendedAlways_"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"SBAutoRelaunchAfterExit"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"SBAutoLaunchOnBootOrInstall"];
    
    [dict writeToFile:@"/var/mobile/tmp/Extender/extracted/Payload/Extender.app/Info.plist" atomically:YES];
    
    xlog(@"Modified Info.plist to allow background execution.");
}

void signBinaries() {
    const char *args1[] = {"/usr/bin/ldid", "-S/var/mobile/tmp/Extender/extender.entitlements", "/var/mobile/tmp/Extender/extracted/Payload/Extender.app/Extender", NULL};
    int val = run_system(args1);
    if (val != 0) {
        xlog(@"ERROR: Failed to fakesign application!");
        xlog(@"*******************************************");
        xlog(@"Try reinstalling 'Link Identity Editor' in Cydia.");
        xlog(@"*******************************************");
        
        cleanup();
        
        exit(1);
    }
    
    const char *args2[] = {"/usr/bin/ldid", "-S/var/mobile/tmp/Extender/vpn.entitlements", "/var/mobile/tmp/Extender/extracted/Payload/Extender.app/PlugIns/Extender.VPN.appex/Extender.VPN", NULL};
    val = run_system(args2);
    if (val != 0) {
        xlog(@"ERROR: Failed to fakesign VPN plugin!");
        xlog(@"*******************************************");
        xlog(@"Try reinstalling 'Link Identity Editor' in Cydia.");
        xlog(@"*******************************************");
        
        cleanup();
        
        exit(1);
    }
    
    xlog(@"Signed binaries.");
}

void install() {
    // We will copy Extender to /Applications.
    
    // First, clear if already existing.
    [[NSFileManager defaultManager] removeItemAtPath:@"/Applications/Extender.app" error:nil];
    
    // Copy across new files.
    [[NSFileManager defaultManager] copyItemAtPath:@"/var/mobile/tmp/Extender/extracted/Payload/Extender.app" toPath:@"/Applications/Extender.app" error:nil];
    
    // We will now check for prior installations that are NOT system.
    // This is to ensure we don't have anything weird going on by duplicating on the same bundle ID.
    // Note: we MUST sign this extrainst_ with the entitlements needed to uninstall an application.
    
    if ([[objc_getClass("LSApplicationWorkspace") defaultWorkspace] applicationIsInstalled:@"com.cydia.Extender"] &&
        ![[objc_getClass("LSApplicationProxy") applicationProxyForIdentifier:@"com.cydia.Extender"] isSystemOrInternalApp]) {
        
        // Not installed as a system app, so uninstall this older version.
        BOOL success = [[objc_getClass("LSApplicationWorkspace") defaultWorkspace] uninstallApplication:@"com.cydia.Extender"withOptions:nil];
        
        if (!success) {
            xlog(@"Failed to uninstall previous version of Cydia Extender. Aborting.");
            xlog(@"*******************************************");
            xlog(@"Please manually delete 'Extender' from your Homescreen and try again.");
            xlog(@"*******************************************");
            
            exit(1);
        }
    }
    
    xlog(@"Proceeding to reload uicache.");
    
    const char *args1[] = {"/usr/bin/uicache", "-c", NULL};
    int val = run_system(args1);
    if (val != 0) {
        xlog(@"ERROR: Failed to reload uicache!");
    } else {
        xlog(@"Installed Cydia Extender.");
    }
}

void cleanup() {
    xlog(@"Cleaning up...");
    
    
    [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/tmp/Extender/" error:nil];
}

void postInstallMigrations() {
    // We need to check if:
    // - We are migrating between 0.3.3 -> 0.3.4 for the Keychain accessibility value.
    // - ?
    
    NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.cydia.Extender.plist"];
    
    id value = [defaults objectForKey:@"migratedFrom033"];
    BOOL migrated = value ? [value boolValue] : NO;
    
    if (!migrated) {
        // Get the password from Keychain.
        
        NSString *username = [defaults objectForKey:@"cachedUsername2"];
        NSString *password = [SAMKeychain passwordForService:@"com.cydia.Extender" account:username];
        
        // Change accessibility.
        [SAMKeychain setAccessibilityType:kSecAttrAccessibleAfterFirstUnlock];
        
        if (password && ![password isEqualToString:@""]) {
            [SAMKeychain setPassword:password forService:@"com.cydia.Extender" account:username];
            
            xlog(@"Migrated Keychain data.");
        }
        
        // Done.
        [defaults setObject:[NSNumber numberWithBool:YES] forKey:@"migratedFrom033"];
        [defaults writeToFile:@"/var/mobile/Library/Preferences/com.cydia.Extender.plist" atomically:YES];
    }
}

int main (int argc, const char * argv[])
{

    @autoreleasepool {
    	// The general idea is that we will attempt to find the user's teamID as installed via
        // impactor/Xcode, and correctly patch the entitlements for Extender as required.
        
        // Note also that Extender is NOT included within this package. This is to avoid any potential
        // issues saurik may raise, which is completely fair enough.
        
        runPreflightChecks();
        
        xlog(@"Downloading Cydia Extender (18.2MB)...");
        xlog(@"This may take some time.");
        
        downloadImpactor();
        
        xlog(@"Extracting Cydia Extender...");
        
        extractExtender();
        
        NSString *teamid = @"AAAAAAAAAA";
        insertTeamIDAndSaveEntitlements(teamid);
        
        modifyInfoPlist();
        
        signBinaries();
        
        install();
        
        postInstallMigrations();
        
        cleanup();
    }
	return 0;
}

#pragma clang diagnostic pop

