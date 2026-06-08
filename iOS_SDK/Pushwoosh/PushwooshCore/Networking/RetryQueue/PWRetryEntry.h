//
//  PWRetryEntry.h
//  Pushwoosh
//
//  Created by André Kis
//

#import <Foundation/Foundation.h>

@class PWRequest;

NS_ASSUME_NONNULL_BEGIN

/// Immutable, serializable snapshot of one retryable network request plus all of
/// its retry bookkeeping. Everything needed to replay the request and to decide
/// when/whether to retry it lives here — there is no external `NSUserDefaults`
/// state keyed by the request.
///
/// The payload (`methodName` + `requestDictionary`) is frozen at enqueue time and
/// replayed verbatim on every attempt. Retry metadata (`attemptCount`,
/// `nextAttemptDate`, `firstEnqueuedDate`) is updated by producing a *new* entry
/// via `-entryByIncrementingAttemptWithNextDate:`, never by mutating in place.
@interface PWRetryEntry : NSObject <NSSecureCoding, NSCopying>

/// Stable identifier copied from the source request. Used as the dedup / in-flight
/// key and to match a server response back to its queue entry.
@property (nonatomic, copy, readonly) NSString *requestIdentifier;

/// Pushwoosh endpoint, e.g. `registerDevice`.
@property (nonatomic, copy, readonly) NSString *methodName;

/// Full frozen request body captured at enqueue time (includes the base fields
/// such as `hwid`/`userId`/`device_type`/`application` as they were then).
@property (nonatomic, copy, readonly) NSDictionary *requestDictionary;

/// Whether the original request wraps its body as `{"request": …}`
/// (`PWRequest.shouldWrapRequest`). Frozen at enqueue so a replay is serialized
/// exactly like the original send, regardless of the request subclass's default.
@property (nonatomic, assign, readonly) BOOL shouldWrapRequest;

/// Per-request base URL override captured at enqueue (`PWRequest.baseUrl`), or
/// `nil` to use the manager's current base URL. Frozen so a replay targets the
/// same host the original send did.
@property (nonatomic, copy, readonly, nullable) NSString *baseUrl;

/// Number of completed send attempts (`0` for a freshly enqueued entry).
@property (nonatomic, assign, readonly) NSUInteger attemptCount;

/// Absolute time before which the next attempt must not start.
@property (nonatomic, copy, readonly) NSDate *nextAttemptDate;

/// Absolute time the entry first entered the queue. Anchor for TTL expiry.
@property (nonatomic, copy, readonly) NSDate *firstEnqueuedDate;

/// Snapshots `request` into a fresh entry: `attemptCount = 0`,
/// `firstEnqueuedDate = nextAttemptDate = now`. Also freezes the request's
/// `shouldWrapRequest` and `baseUrl` so the replay matches the original send.
- (instancetype)initWithRequest:(PWRequest *)request now:(NSDate *)now;

/// Designated initializer. Used by `initWithCoder:` and by
/// `-entryByIncrementingAttemptWithNextDate:`.
- (instancetype)initWithRequestIdentifier:(NSString *)requestIdentifier
                               methodName:(NSString *)methodName
                        requestDictionary:(NSDictionary *)requestDictionary
                        shouldWrapRequest:(BOOL)shouldWrapRequest
                                  baseUrl:(nullable NSString *)baseUrl
                             attemptCount:(NSUInteger)attemptCount
                          nextAttemptDate:(NSDate *)nextAttemptDate
                        firstEnqueuedDate:(NSDate *)firstEnqueuedDate NS_DESIGNATED_INITIALIZER;

/// Convenience initializer defaulting to the standard transport
/// (`shouldWrapRequest = YES`, no `baseUrl` override).
- (instancetype)initWithRequestIdentifier:(NSString *)requestIdentifier
                               methodName:(NSString *)methodName
                        requestDictionary:(NSDictionary *)requestDictionary
                             attemptCount:(NSUInteger)attemptCount
                          nextAttemptDate:(NSDate *)nextAttemptDate
                        firstEnqueuedDate:(NSDate *)firstEnqueuedDate;

- (instancetype)init NS_UNAVAILABLE;

/// Returns a copy with `attemptCount` incremented by one and `nextAttemptDate`
/// set to `nextDate`. The receiver is unchanged.
- (PWRetryEntry *)entryByIncrementingAttemptWithNextDate:(NSDate *)nextDate;

@end

NS_ASSUME_NONNULL_END
