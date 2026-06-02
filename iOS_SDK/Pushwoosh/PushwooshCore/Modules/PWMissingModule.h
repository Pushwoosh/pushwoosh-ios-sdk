//
//  PWMissingModule.h
//  PushwooshCore
//
//  Created by André Kis on 21.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Universal no-op proxy returned by `PushwooshModuleRegistry` when a module
 identifier has no registered implementation class.

 Behavioural contract:
 * `+respondsToSelector:` returns `YES` for any selector — callers don't have
   to branch around missing modules.
 * `+forwardInvocation:` logs once per `(class, selector)` pair via
   `PushwooshLog` at `PW_LL_INFO` and writes a zeroed return value so primitive
   returns become `0`/`NO` and object returns become `nil`.

 Visibility: project-only. Not exposed in `PushwooshCore.h`.
 */
@interface PWMissingModule : NSObject

/// Test seam — clears the "logged once" set so that test cases that depend on
/// observing the log output can run in any order. NOT exposed in release headers.
+ (void)_resetLogStateForTesting;

@end

NS_ASSUME_NONNULL_END
