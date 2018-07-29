//
//  EEBackend.h
//  OpenExtenderTest
//
//  Created by Matt Clarke on 02/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EEAppleServices.h"

/**
 EEBackend provides an easy interface through which to sign a given IPA file.
 
 The Apple ID credentials passed to the below methods are ONLY sent to Apple. You can verify
 this yourself by studying the source code.
 */
@interface EEBackend : NSObject

/**
 * TODO: Docs!
 */
+ (void)provisionDevice:(NSString*)udid name:(NSString*)name username:(NSString*)username password:(NSString*)password priorChosenTeamID:(NSString*)teamId systemType:(EESystemType)systemType withCallback:(void (^)(NSError *))completionHandler;

/**
 * TODO: Docs!
 */
+ (void)revokeDevelopmentCertificatesForCurrentMachineWithUsername:(NSString*)username password:(NSString*)password priorChosenTeamID:(NSString*)teamId systemType:(EESystemType)systemType withCallback:(void (^)(NSError *))completionHandler;

/**
 * TODO: Docs!
 */
+ (void)signBundleAtPath:(NSString*)path username:(NSString*)username password:(NSString*)password priorChosenTeamID:(NSString*)teamId withCompletionHandler:(void (^)(NSError *))completionHandler;

/**
 Signs the IPA specified at the inputPath, then outputs it to the outputPath. *simple*.
 
 @param ipaPath The path the IPA to sign is currently available at.
 @param outputPath The path to write the signed IPA to. This can be the same as the inputPath
 @param username The username of the Apple ID used to sign with
 @param password The password of the Apple ID used to sign with.
 @param teamId If the user's Apple ID is associated with multiple developer accounts, this is the Team ID that should be used.
 @param completionHandler Called once the IPA is signed and present at the outputPath. If any errors occurred during the process, the first parameter of the completionHandler will contain further information.
 */
+ (void)signIpaAtPath:(NSString*)ipaPath outputPath:(NSString*)outputPath username:(NSString*)username password:(NSString*)password priorChosenTeamID:(NSString*)teamId withCompletionHandler:(void (^)(NSError *))completionHandler;

/**
 Unpacks the contents of the specified IPA into a directory.
 @param ipaPath Path to the IPA to unpack
 @param outputDirectory A pointer that will be updated to the directory the IPA is unpacked to
 @param error A pointer will be updated with any errors that occurred.
 @return Success or failure
 */
+ (BOOL)unpackIpaAtPath:(NSString*)ipaPath outDirectory:(NSString**)outputDirectory error:(NSError**)error;

/**
 Repacks the contents of the IPA directory structure into an IPA file.
 @param extractedPath Path to the IPA directory structure to repack
 @param outputPath Path where the IPA should be written
 @param error A pointer will be updated with any errors that occurred.
 @return Success or failure
 */
+ (BOOL)repackIpaAtPath:(NSString*)extractedPath toPath:(NSString*)outputPath error:(NSError**)error;

/**
 Asks sandboxing APIs for a temporary directory to use.
 @return The temporary directory the current application can utilise.
 */
+ (NSString*)applicationTemporaryDirectory;

@end
