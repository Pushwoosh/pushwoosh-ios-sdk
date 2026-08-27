//
//  PWSdkStateProvider.h
//  PushwooshCore
//
//  Created by André Kis
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PWSdkState) {
    PWSdkStateInitializing,
    PWSdkStateReady,
    PWSdkStateError
};

/// What `-queueUnlessReady:` did with the task it was handed.
typedef NS_ENUM(NSInteger, PWSdkQueueDecision) {
    PWSdkQueueDecisionSendNow,   // ready — the task was not touched, run it yourself
    PWSdkQueueDecisionQueued,    // initializing — the task is in the queue
    PWSdkQueueDecisionDropped    // error — the task was discarded and the drop was logged
};

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const kPWAppCodeUpdatedNotification;

/// Posted before the application code moves (never for an endpoint-only move or a repeat), for work
/// only possible under the previous application. Best effort — the changed notification is the backstop.
FOUNDATION_EXPORT NSNotificationName const kPWActiveApplicationWillChangeNotification;

/// Posted after a new (application code, base URL) pair is committed; everything produced under the
/// previous pair is stale.
FOUNDATION_EXPORT NSNotificationName const kPWActiveApplicationChangedNotification;

/// `userInfo` key: NSNumber-wrapped BOOL, YES when the application code moved, NO for an endpoint-only
/// move. Absent = treat as YES (fail towards isolation).
FOUNDATION_EXPORT NSString * const kPWActiveApplicationChangedAppCodeChangedKey;

@interface PWSdkStateProvider : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) PWSdkState currentState;

- (BOOL)isReady;

- (void)executeOrQueue:(dispatch_block_t)task;

/// Decides and acts under one acquisition of the provider's lock: the task is queued (initializing),
/// discarded (error), or left untouched when ready so the caller can run it outside the lock.
- (PWSdkQueueDecision)queueUnlessReady:(dispatch_block_t)task;

- (void)setReady;

- (void)setError;

@end

NS_ASSUME_NONNULL_END
