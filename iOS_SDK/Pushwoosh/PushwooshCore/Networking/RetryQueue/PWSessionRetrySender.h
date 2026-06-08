//
//  PWSessionRetrySender.h
//  Pushwoosh
//
//  Created by André Kis
//

#import <Foundation/Foundation.h>

@class PWRequest;
@class PWRequestManager;
@class PWRetryPolicy;

NS_ASSUME_NONNULL_BEGIN

/// Short, in-memory retry for requests that must NOT be persisted to the offline
/// queue (e.g. `registerDevice`, which is idempotent and re-sent on the next app
/// open anyway). Mirrors the Android SDK's `RetriableRequestCallback`: a few quick
/// attempts within the session, then give up — nothing is written to disk, so
/// pending retries are lost on app kill (by design).
///
/// Retriability is delegated to `PWRetryPolicy` (same status-code set as the
/// persistent queue). The request object is re-sent as-is, so its payload is
/// rebuilt fresh (current hwid/token) on every attempt.
@interface PWSessionRetrySender : NSObject

- (instancetype)initWithRequestManager:(PWRequestManager *)requestManager
                                policy:(PWRetryPolicy *)policy NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Delays (seconds) before each retry attempt. Count = max number of retries.
/// Default `@[@1, @5, @10]` — matching the Android SDK.
@property (nonatomic, copy) NSArray<NSNumber *> *retryDelaysSeconds;

/// Sends `request`; on a retriable failure waits and retries up to
/// `retryDelaysSeconds.count` times, then calls `completion` with the last result.
/// Success or a non-retriable failure calls `completion` immediately.
- (void)sendWithRetry:(PWRequest *)request completion:(void (^ _Nullable)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
