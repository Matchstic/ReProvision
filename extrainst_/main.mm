//
//  main.m
//  Extender Installer
//
//  Created by Matt Clarke on 13/04/2017.
//  Copyright (c) 2017 Matchstic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SSZipArchive/SSZipArchive.h"
#include <spawn.h>

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

void downloadImpactor() {
    [[NSFileManager defaultManager] createDirectoryAtPath:@"/tmp/Extender/" withIntermediateDirectories:NO attributes:nil error:nil];
    
    NSString *stringURL = @"https://cydia.saurik.com/api/latest/2";
    NSURL  *url = [NSURL URLWithString:stringURL];
    NSData *urlData = [NSData dataWithContentsOfURL:url];
    if (urlData) {
        NSString  *filePath = @"/tmp/Extender/Impactor.zip";
        [urlData writeToFile:filePath atomically:YES];
    } else {
        xlog(@"Failed to download Cydia Extender. Aborting.");
        xlog(@"\n\n\n\n*******************************************");
        xlog(@"Try installing again another time.");
        xlog(@"*******************************************\n\n\n\n");
    }
    
    xlog(@"Downloaded.");
}

void extractExtender() {
    [SSZipArchive unzipFileAtPath:@"/tmp/Extender/Impactor.zip" toDestination:@"/tmp/Extender/Impactor/"];
    [SSZipArchive unzipFileAtPath:@"/tmp/Extender/Impactor/Impactor.dat" toDestination:@"/tmp/Extender/Impactor/Dat/"];
    
    // We will now pull out the ipa, and move it somewhere a little more sane.
    [[NSFileManager defaultManager] copyItemAtPath:@"/tmp/Extender/Impactor/Dat/extender.ipa" toPath:@"/tmp/Extender/extender.ipa" error:nil];
    
    [SSZipArchive unzipFileAtPath:@"/tmp/Extender/extender.ipa" toDestination:@"/tmp/Extender/extracted/"];
    
    xlog(@"Extracted to /tmp/Extender/extracted/");
    
    // Cleanup.
    [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/Extender/Impactor.zip" error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/Extender/Impactor/" error:nil];
}

NSString *extractTeamID() {
    // To make our lives easier, we will search for yalu102.app and mach_portal.app, nothing else.
    NSString *teamid = @"";
    
    NSString *base = @"/var/containers/Bundle/Application";
    NSArray *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:base error:nil];
    for (NSString *string in filenames) {
        
        NSString *path1 = [NSString stringWithFormat:@"%@/%@/yalu102.app", base, string];
        NSString *path2 = [NSString stringWithFormat:@"%@/%@/mach_portal.app", base, string];
        
        NSString *actualPath = [NSString stringWithFormat:@"%@/%@/", base, string];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:path1]) {
            actualPath = [actualPath stringByAppendingString:@"yalu102.app"];
            xlog(@"Found yalu102.app");
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:path2]) {
            actualPath = [actualPath stringByAppendingString:@"mach_portal.app"];
            xlog(@"Found mach_portal.app");
        } else {
            continue;
        }
        
        // We will now read the mobileprovision plist.
        NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@/embedded.mobileprovision", actualPath]];
        
        // Since straight reading the file is weird, we'll make a copy, and strip out stuff that isn't needed.
        // Then, we can read it as a plist.
        [[NSFileManager defaultManager] copyItemAtPath:[URL path] toPath:@"/tmp/Extender/provision.plist" error:nil];
        
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:@"/tmp/Extender/provision.plist"];
        if (!data) {
            xlog(@"ERROR: Failed to copy provisioning plist!");
            break;
        }
        
        // Strip until '<'
        unsigned int index = [data rangeOfData:[NSData dataWithBytes:"<" length:1] options:0 range:NSMakeRange(0, data.length)].location;
        
        data = [data subdataWithRange:NSMakeRange(index, data.length - index)];
        
        // Strip after </plist>
        
        index = [data rangeOfData:[NSData dataWithBytes:"</plist>" length:8] options:0 range:NSMakeRange(0, data.length)].location;
        index += 8;
        
        data = [data subdataWithRange:NSMakeRange(0, index)];
        
        [data writeToFile:@"/tmp/Extender/provision.plist" atomically:NO];
        
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/tmp/Extender/provision.plist"];
        if (dict) {
            teamid = [[dict objectForKey:@"ApplicationIdentifierPrefix"] firstObject];
            break;
        }
    }
    
    xlog([NSString stringWithFormat:@"Got TeamID: %@", teamid]);
    
    return teamid;
}

void insertTeamIDAndSaveEntitlements(NSString *teamid) {
    vpnEntitlements = [vpnEntitlements stringByReplacingOccurrencesOfString:@"AAAAAAAAAA" withString:teamid];
    extenderEntitlements = [extenderEntitlements stringByReplacingOccurrencesOfString:@"AAAAAAAAAA" withString:teamid];
    
    // Write plists.
    NSData *vpnData = [NSData dataWithBytes:[vpnEntitlements UTF8String] length:vpnEntitlements.length];
    if (vpnData) {
        NSString *filePath = @"/tmp/Extender/vpn.entitlements";
        [vpnData writeToFile:filePath atomically:YES];
    }
    
    NSData *extenderData = [NSData dataWithBytes:[extenderEntitlements UTF8String] length:extenderEntitlements.length];
    if (extenderData) {
        NSString *filePath = @"/tmp/Extender/extender.entitlements";
        [extenderData writeToFile:filePath atomically:YES];
    }
    
    xlog(@"Wrote entitlements to disk.");
}

void modifyInfoPlist() {
    // We need to add background modes to Extender for auto-signing.
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:@"/tmp/Extender/extracted/Payload/Extender.app/Info.plist"];
    
    NSArray *modes = @[@"continuous", @"remote-notification", @"audio", @"fetch"];
    [dict setObject:modes forKey:@"UIBackgroundModes"];
    
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"SBAppUsesLocalNotifications"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"SBLaunchSuspendedAlways_"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"SBAutoRelaunchAfterExit"];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"SBAutoLaunchOnBootOrInstall"];
    
    [dict writeToFile:@"/tmp/Extender/extracted/Payload/Extender.app/Info.plist" atomically:YES];
    
    xlog(@"Modified Info.plist to allow background execution.");
}

void signBinaries() {
    const char *args1[] = {"/usr/bin/ldid", "-S/tmp/Extender/extender.entitlements", "/tmp/Extender/extracted/Payload/Extender.app/Extender", NULL};
    int val = run_system(args1);
    if (val != 0) {
        xlog(@"ERROR: Failed to fakesign application!");
    }
    
    const char *args2[] = {"/usr/bin/ldid", "-S/tmp/Extender/vpn.entitlements", "/tmp/Extender/extracted/Payload/Extender.app/PlugIns/Extender.VPN.appex/Extender.VPN", NULL};
    val = run_system(args2);
    if (val != 0) {
        xlog(@"ERROR: Failed to fakesign VPN plugin!");
    }
    
    xlog(@"Signed binaries.");
}

void install() {
    // We will copy Extender to /Applications. Might not be the best solution, but should avoid the need for
    // App Installer (appinst).
    
    // First, clear if already existing.
    [[NSFileManager defaultManager] removeItemAtPath:@"/Applications/Extender.app" error:nil];
    
    // Copy across new files.
    [[NSFileManager defaultManager] copyItemAtPath:@"/tmp/Extender/extracted/Payload/Extender.app" toPath:@"/Applications/Extender.app" error:nil];
    
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
    
    [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/Extender/" error:nil];
}

void classicMatchsticEasterEgg() {
    xlog(@"\n\nI'm trying to free your mind, Neo. But I can only show you the door. You're the one that has to walk through it.");
}

int main (int argc, const char * argv[])
{

    @autoreleasepool {
    	// The general idea is that we will attempt to find the user's teamID as installed via
        // impactor/Xcode, and correctly patch the entitlements for Extender as required.
        
        // Note also that Extender is NOT included within this package. This is to avoid any potential
        // issues saurik may raise, which is completely fair enough.
        
        xlog(@"Downloading Cydia Extender (18.2MB)...");
        xlog(@"This may take some time.");
        
        downloadImpactor();
        
        xlog(@"Extracting Cydia Extender...");
        
        extractExtender();
        
        xlog(@"Finding TeamID...");
        // TODO: Remove need to find the Team ID here.
        
        NSString *teamid = extractTeamID();
        if (!teamid || [teamid isEqualToString:@""]) {
            xlog(@"FATAL: Could not find TeamID. Aborting.");
            xlog(@"Note this installation script only searches for 'mach_portal.app' and 'yalu102.app'.");
            xlog(@"\n\n\n\n*******************************************");
            xlog(@"This is a known issue, and will be fixed in a future update. Please keep an eye on my Twitter @_Matchstic for updates.");
            xlog(@"*******************************************\n\n\n\n");
            exit(1);
        }
        
        insertTeamIDAndSaveEntitlements(teamid);
        
        modifyInfoPlist();
        
        signBinaries();
        
        install();
        
        cleanup();
        
        classicMatchsticEasterEgg();
    }
	return 0;
}

#pragma clang diagnostic pop

