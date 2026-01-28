//
//  PWSystemCommandHandler.h
//  PushwooshCore
//
//  Created by André Kis on 26.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Protocol for handling system commands received via push notifications.

 System commands are identified by the presence of "pw_system_push" = 1 in the push payload,
 along with a "pw_command" field specifying the command name.

 Push format:
 @code
 {
   "pw_system_push": 1,
   "pw_command": "setLogLevel",
   "value": "INFO"
 }
 @endcode

 @discussion
 Implement this protocol to create custom command handlers. Each handler is responsible
 for processing a specific command identified by its `commandName` property.

 Example implementation:
 @code
 @interface MyCommandHandler : NSObject <PWSystemCommandHandler>
 @end

 @implementation MyCommandHandler

 - (NSString *)commandName {
     return @"myCommand";
 }

 - (BOOL)handleCommand:(NSDictionary *)userInfo {
     NSString *value = userInfo[@"value"];
     // Process command...
     return YES;
 }

 @end
 @endcode
 */
@protocol PWSystemCommandHandler <NSObject>

@required

/**
 The name of the command this handler processes.

 @return Command name string that matches the "pw_command" field in push payload.
 */
@property (nonatomic, readonly) NSString *commandName;

/**
 Handles the system command.

 @param userInfo The push notification payload dictionary containing command data.
 @return YES if the command was successfully handled, NO otherwise.

 @discussion
 The handler should extract necessary values from userInfo (typically from the "value" key)
 and perform the appropriate action. Return YES to indicate successful handling.
 */
- (BOOL)handleCommand:(NSDictionary *)userInfo;

@end

NS_ASSUME_NONNULL_END
