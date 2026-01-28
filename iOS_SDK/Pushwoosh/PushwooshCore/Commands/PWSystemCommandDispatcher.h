//
//  PWSystemCommandDispatcher.h
//  PushwooshCore
//
//  Created by André Kis on 26.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWSystemCommandHandler.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Dispatcher for system commands received via push notifications.

 @discussion
 This class manages the registration and dispatching of system command handlers.
 It processes push payloads and routes commands to appropriate handlers based on
 the "pw_command" field.

 System push format:
 @code
 {
   "pw_system_push": 1,
   "pw_command": "setLogLevel",
   "value": "INFO"
 }
 @endcode

 Usage:
 @code
 // Register a custom handler
 [[PWSystemCommandDispatcher shared] registerHandler:[[MyCommandHandler alloc] init]];

 // Process push payload (called internally by SDK)
 BOOL handled = [[PWSystemCommandDispatcher shared] processUserInfo:userInfo];
 @endcode
 */
@interface PWSystemCommandDispatcher : NSObject

/**
 Returns the shared dispatcher instance.

 @return The singleton PWSystemCommandDispatcher instance.
 */
+ (instancetype)shared;

/**
 Registers a command handler with the dispatcher.

 @param handler An object conforming to PWSystemCommandHandler protocol.

 @discussion
 If a handler for the same command name is already registered, it will be replaced.
 Built-in handlers (like setLogLevel) are registered automatically during SDK initialization.
 */
- (void)registerHandler:(id<PWSystemCommandHandler>)handler;

/**
 Unregisters a command handler.

 @param commandName The name of the command to unregister.
 */
- (void)unregisterHandlerForCommand:(NSString *)commandName;

/**
 Processes the push notification payload for system commands.

 @param userInfo The push notification payload dictionary.
 @return YES if this was a system push and a command was handled, NO otherwise.

 @discussion
 This method checks if the payload contains "pw_system_push" = 1, and if so,
 extracts the "pw_command" field and dispatches to the appropriate handler.

 If the command is handled successfully, the push notification should not be
 displayed to the user (it's an internal SDK command).
 */
- (BOOL)processUserInfo:(NSDictionary *)userInfo;

@end

NS_ASSUME_NONNULL_END
