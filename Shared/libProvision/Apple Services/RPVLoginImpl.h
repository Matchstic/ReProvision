//
//  RPVLoginImpl.hpp
//  iOS
//
//  Created by Matt Clarke on 24/11/2019.
//  Copyright © 2019 Matt Clarke. All rights reserved.
//

#ifndef RPVLoginImpl_hpp
#define RPVLoginImpl_hpp

#import <Foundation/Foundation.h>

#define RPVInternalLoginError 500

// do a typedef for the block
typedef void (^RPVLoginResultBlock)(NSError *error, NSString *userIdentity, NSString *gsToken);

#ifdef __cplusplus
extern "C" {
#endif

void perform_login(NSString *username, NSString *password, RPVLoginResultBlock completionHandler);

#ifdef __cplusplus
}
#endif

#endif /* RPVLoginImpl_hpp */
