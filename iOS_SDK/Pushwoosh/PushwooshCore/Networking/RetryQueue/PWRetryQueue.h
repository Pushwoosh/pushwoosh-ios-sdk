//
//  PWRetryQueue.h
//  Pushwoosh
//
//  Created by André Kis
//

#import <Foundation/Foundation.h>
#import "PWRetryTransport.h"

@class PWRequest;
@class PWRetryPolicy;
@class PWRetryQueueStorage;

NS_ASSUME_NONNULL_BEGIN

/// Posted on the main queue when a queued request whose `announcesRetryDelivery` is YES is delivered;
/// `userInfo`: its method under `PWRetryQueueMethodNameKey`, its body under `PWRetryQueueBodyKey`.
FOUNDATION_EXPORT NSNotificationName const PWRetryQueueDidDeliverRequestNotification;
FOUNDATION_EXPORT NSString *const PWRetryQueueMethodNameKey;
FOUNDATION_EXPORT NSString *const PWRetryQueueBodyKey;

/// Offline retry engine. Owns the in-memory queue of `PWRetryEntry`s, persists it
/// through `PWRetryQueueStorage`, decides timing/eligibility through `PWRetryPolicy`,
/// dedups in-flight sends by `requestIdentifier`, and replays due entries through a
/// `PWRetryTransport`.
///
/// Thread-safe: every mutation of the queue and the in-flight set runs on a private
/// serial queue. Public methods may be called from any thread.
@interface PWRetryQueue : NSObject

- (instancetype)initWithTransport:(id<PWRetryTransport>)transport
                           policy:(PWRetryPolicy *)policy
                          storage:(PWRetryQueueStorage *)storage NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Snapshot `request` into the queue and persist. No-op if an entry with the same
/// `requestIdentifier` is already queued. Over the request's `retryQueueLimit` the oldest entries
/// of its method are dropped. Triggers a flush.
- (void)enqueueRequest:(PWRequest *)request;

/// Same as `-enqueueRequest:` but the caller decides which host a replay must target.
/// `nil` = replay against whatever base URL is current at replay time (legacy behaviour).
- (void)enqueueRequest:(PWRequest *)request baseUrl:(nullable NSString *)baseUrl;

/// Attempt every due, not-in-flight entry; drop expired/exhausted ones. Safe to
/// call repeatedly and from any thread.
- (void)flush;

/// Drops every queued entry (except survivors) on an application change: entries built for the
/// previous application must never be replayed into the new one.
- (void)purgeAllEntriesWithReason:(NSString *)reason;

/// Hook for the reachability observer: connectivity restored, so entries waiting for the network are due and the queue flushes now.
- (void)onNetworkReachable;

@end

NS_ASSUME_NONNULL_END
