//
//  PWNotificationServiceProcessor.h
//  Pushwoosh SDK
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

#if TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

/**
 Internal processor that performs all Notification Service Extension work — badge counting, the
 message delivery event and the media attachment download — and serializes every content mutation
 and the final delivery decision onto a single serial queue, so the system content handler runs
 exactly once even when the timeout fallback races normal completion.

 Not part of the public API: this header is project-visibility and is excluded from the
 PushwooshFramework.h umbrella.
 */
API_AVAILABLE(ios(10.0))
@interface PWNotificationServiceProcessor : NSObject

/**
 Arms the processor with a request and its delivery callbacks. Captures a best-attempt content
 (mutableCopy of request.content) synchronously, so expireWithFallback can deliver something even
 if the timeout fires before process runs (e.g. while an async prepare hook is still running).

 Call this at the very start of handling, before any async preparation, then call process.

 @param request The original notification request.
 @param appGroupsName Resolved App Group name, or nil.
 @param completion The system content handler. Invoked exactly once on the main thread.
 */
- (void)armWithRequest:(UNNotificationRequest *)request
             appGroups:(nullable NSString *)appGroupsName
            completion:(void (^)(UNNotificationContent *))completion;

/**
 Runs the processing for the armed request. A non-Pushwoosh message is delivered immediately; a
 Pushwoosh message runs the badge/delivery/attachment tasks concurrently and applies every content
 mutation on the serial queue before finalizing. Must be called after armWithRequest:.
 */
- (void)process;

/**
 Convenience that arms the processor and immediately processes the request. Use when there is no
 async preparation step between arming and processing.

 @param request The original notification request.
 @param appGroupsName Resolved App Group name, or nil.
 @param completion The system content handler. Invoked exactly once on the main thread.
 */
- (void)processRequest:(UNNotificationRequest *)request
             appGroups:(nullable NSString *)appGroupsName
            completion:(void (^)(UNNotificationContent *))completion;

/**
 Delivers the current best-attempt content if nothing has been delivered yet. Safe to call from
 any thread; serialized via the processor's queue.
 */
- (void)expireWithFallback;

@end

NS_ASSUME_NONNULL_END

#endif
