//
//  PWRetryPolicy.h
//  Pushwoosh
//
//  Created by André Kis
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Stateless decision logic for the offline retry queue: which failures are worth
/// retrying, how long to back off before the next attempt, and when to give up
/// (attempt cap or TTL). All methods are pure functions of their inputs (the only
/// non-determinism is jitter in `-delayForAttempt:`), so they unit-test without mocks.
///
/// Tunables have sensible defaults set in `-init`; override them before use.
@interface PWRetryPolicy : NSObject

/// Seed of the escalating backoff (the legacy `t * log2(t)` recurrence), in
/// seconds. Default 25 — the value the previous SDK used, so the delay curve
/// matches the old client (~2 min → ~13 min → ~2 h).
@property (nonatomic, assign) NSTimeInterval baseDelay;

/// Upper bound for any single backoff delay, in seconds. Default 21600 (6 hours)
/// — a runaway backstop; the default 3-attempt curve stays well under it.
@property (nonatomic, assign) NSTimeInterval maxDelay;

/// Lower bound for any single backoff delay, in seconds, applied after jitter so a
/// network flap can't produce a near-zero delay. Default 2.
@property (nonatomic, assign) NSTimeInterval minDelay;

/// Fraction of full jitter applied to each delay, in `[0, 1]`. Default 0.25 (±25%).
@property (nonatomic, assign) double jitterFraction;

/// Number of attempts after which an entry is considered exhausted. Default 3,
/// matching the legacy retry budget the backend is built around (it observed
/// `X-Retry-Count` up to 3); the queue sends at attempt 0/1/2 → `X-Retry-Count`
/// 1/2/3, then drops.
@property (nonatomic, assign) NSUInteger maxAttempts;

/// Maximum age of an entry before it is dropped unsent, in seconds. Default 259200 (3 days).
/// Set to 0 to disable TTL.
@property (nonatomic, assign) NSTimeInterval timeToLive;

/// Maximum time an entry may stay marked in-flight before the queue assumes the
/// transport completion was lost and reclaims it as a failed attempt, in seconds.
/// Guards against an entry pinned forever if a send never reports back. Default 120
/// — deliberately above the retry transport's 80s total timeout, so a normal send
/// always completes (success or timeout) before the watchdog can reclaim it, which
/// prevents a slow-but-alive send from being duplicated by a reclaim.
@property (nonatomic, assign) NSTimeInterval inFlightTimeout;

/// YES when a failure is transient and worth retrying. The HTTP status set matches
/// the Android SDK exactly — 408, 429, 500, 502, 503, 504 — plus a curated subset
/// of "no response" transport errors (timeout, connection lost, not connected,
/// cannot connect to host, DNS failure, roaming disallowed); note Android retries
/// any connection failure here, so iOS is slightly stricter on transport errors.
/// Also YES for the "server communication disabled" control error (`PWErrorDomain` /
/// `PWErrorCommunicationDisabled`): it is re-enableable, so the entry is kept and
/// retried once communication returns rather than dropped. NO for any other status
/// (incl. other 4xx/5xx such as 501/505), cancellation, TLS/certificate errors, and success.
- (BOOL)shouldRetryStatusCode:(NSInteger)statusCode error:(nullable NSError *)error;

/// Escalating backoff with jitter for the given completed-attempt count. Applies
/// the legacy recurrence `v = v * log2(v)` (seeded with `baseDelay`) `attemptCount + 1`
/// times, then `± jitterFraction` jitter, clamped to `[minDelay, maxDelay]`.
/// With the default seed 25 this yields ≈116 s, ≈796 s, ≈7676 s for attempts 0/1/2.
- (NSTimeInterval)delayForAttempt:(NSUInteger)attemptCount;

/// YES when `attemptCount` has reached `maxAttempts`.
- (BOOL)isExhaustedAttemptCount:(NSUInteger)attemptCount;

/// YES when `firstEnqueuedDate` is older than `timeToLive` relative to `now`.
/// Always NO when `timeToLive == 0`.
- (BOOL)isExpiredFirstEnqueuedDate:(NSDate *)firstEnqueuedDate now:(NSDate *)now;

@end

NS_ASSUME_NONNULL_END
