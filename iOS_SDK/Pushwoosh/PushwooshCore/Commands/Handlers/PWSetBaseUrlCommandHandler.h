//
//  PWSetBaseUrlCommandHandler.h
//  PushwooshCore
//
//  Created by André Kis on 26.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWSystemCommandHandler.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Handler for the "set_base_url" system command.

 @discussion
 This handler processes the set_base_url command received via push notifications,
 allowing remote control of SDK API base URL.

 Push format:
 @code
 {
   "pw_system_push": 1,
   "pw_command": "set_base_url",
   "value": "https://new-api.pushwoosh.com/json/1.3/"
 }
 @endcode

 @note The base URL change is persisted to NSUserDefaults and takes effect immediately
 for all subsequent API requests.
 */
@interface PWSetBaseUrlCommandHandler : NSObject <PWSystemCommandHandler>

@end

NS_ASSUME_NONNULL_END
