//
//  PWSetLogLevelCommandHandler.h
//  PushwooshCore
//
//  Created by André Kis on 26.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWSystemCommandHandler.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Handler for the "setLogLevel" system command.

 @discussion
 This handler processes the setLogLevel command received via push notifications,
 allowing remote control of SDK logging verbosity.

 Push format:
 @code
 {
   "pw_system_push": 1,
   "pw_command": "setLogLevel",
   "value": "INFO"
 }
 @endcode

 Supported log level values (case-insensitive):
 - "NONE" - No logs
 - "ERROR" - Errors only
 - "WARN" or "WARNING" - Warnings and errors
 - "INFO" - Info, warnings, and errors (default)
 - "DEBUG" - Debug messages and above
 - "VERBOSE" - All messages

 @note The log level change is persisted to NSUserDefaults and takes effect immediately.
 */
@interface PWSetLogLevelCommandHandler : NSObject <PWSystemCommandHandler>

@end

NS_ASSUME_NONNULL_END
