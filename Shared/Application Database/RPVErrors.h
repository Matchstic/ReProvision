//
//  RPVErrors.h
//  ReProvision
//
//  Created by Matt Clarke on 11/01/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#ifndef RPVErrors_h
#define RPVErrors_h

/* RPVApplicationSigning errors */

// The previous set of applications are still being worked upon
#define RPVErrorAlreadyUndertakingPipeline 100

// No applications need re-signing
#define RPVErrorNoSigningRequired 101

// Failed to copy the .app of an application to a temporary directory
#define RPVErrorFailedToCopyBundle 102

// Failed to install the signed IPA
#define RPVErrorFailedToInstallSignedIPA 103

/* libProvision errors */


#endif /* RPVErrors_h */
