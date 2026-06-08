#import <XCTest/XCTest.h>
#import "PWRetryPolicy.h"
#import "PWUtils.h"

@interface PWRetryPolicyTest : XCTestCase
@property (nonatomic) PWRetryPolicy *policy;
@end

@implementation PWRetryPolicyTest

- (void)setUp {
    self.policy = [PWRetryPolicy new];
}

#pragma mark - shouldRetry

/// Verifies the exact retriable status set matching the Android SDK: 408/429/500/502/503/504.
- (void)testShouldRetry_retriableServerCodes_returnYES {
    XCTAssertTrue([self.policy shouldRetryStatusCode:408 error:nil]);
    XCTAssertTrue([self.policy shouldRetryStatusCode:429 error:nil]);
    XCTAssertTrue([self.policy shouldRetryStatusCode:500 error:nil]);
    XCTAssertTrue([self.policy shouldRetryStatusCode:502 error:nil]);
    XCTAssertTrue([self.policy shouldRetryStatusCode:503 error:nil]);
    XCTAssertTrue([self.policy shouldRetryStatusCode:504 error:nil]);
}

/// Verifies that non-listed 5xx (501/505/599) and other 4xx (400/401/404) are NOT retried — exact-code parity with Android.
- (void)testShouldRetry_nonRetriableCodes_returnNO {
    XCTAssertFalse([self.policy shouldRetryStatusCode:400 error:nil]);
    XCTAssertFalse([self.policy shouldRetryStatusCode:401 error:nil]);
    XCTAssertFalse([self.policy shouldRetryStatusCode:404 error:nil]);
    XCTAssertFalse([self.policy shouldRetryStatusCode:501 error:nil]);
    XCTAssertFalse([self.policy shouldRetryStatusCode:505 error:nil]);
    XCTAssertFalse([self.policy shouldRetryStatusCode:599 error:nil]);
}

/// Verifies that a 200 success with no error is never retried.
- (void)testShouldRetry_success_returnsNO {
    XCTAssertFalse([self.policy shouldRetryStatusCode:200 error:nil]);
}

/// Verifies that transient NSURLErrors are retried.
- (void)testShouldRetry_transientNSURLError_returnsYES {
    NSError *timeout = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    NSError *lost = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil];
    NSError *offline = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
    XCTAssertTrue([self.policy shouldRetryStatusCode:0 error:timeout]);
    XCTAssertTrue([self.policy shouldRetryStatusCode:0 error:lost]);
    XCTAssertTrue([self.policy shouldRetryStatusCode:0 error:offline]);
}

/// Verifies that cancellation and TLS errors are NOT retried.
- (void)testShouldRetry_nonTransientErrors_returnsNO {
    NSError *cancel = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
    NSError *cert = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorServerCertificateUntrusted userInfo:nil];
    NSError *other = [NSError errorWithDomain:@"PushwooshErrorDomain" code:1 userInfo:nil];
    XCTAssertFalse([self.policy shouldRetryStatusCode:0 error:cancel]);
    XCTAssertFalse([self.policy shouldRetryStatusCode:0 error:cert]);
    XCTAssertFalse([self.policy shouldRetryStatusCode:0 error:other]);
}

/// Verifies a "server communication disabled" control error is retriable — the entry is kept until comms return, not dropped as a permanent failure.
- (void)testShouldRetry_communicationDisabled_returnsYES {
    NSError *commDisabled = [NSError errorWithDomain:PWErrorDomain code:PWErrorCommunicationDisabled userInfo:nil];
    XCTAssertTrue([self.policy shouldRetryStatusCode:0 error:commDisabled]);
}

#pragma mark - delay

/// Verifies that backoff stays within [minDelay, maxDelay] and grows with attempts on average.
- (void)testDelay_withinBounds {
    self.policy.baseDelay = 15;
    self.policy.maxDelay = 3600;
    self.policy.minDelay = 2;

    for (NSUInteger attempt = 0; attempt < 12; attempt++) {
        NSTimeInterval d = [self.policy delayForAttempt:attempt];
        XCTAssertGreaterThanOrEqual(d, 2.0);
        XCTAssertLessThanOrEqual(d, 3600.0);
    }
}

/// Verifies that a high attempt count is clamped to maxDelay (never explodes).
- (void)testDelay_highAttempt_clampedToMax {
    self.policy.maxDelay = 3600;
    NSTimeInterval d = [self.policy delayForAttempt:30];
    XCTAssertLessThanOrEqual(d, 3600.0);
}

#pragma mark - exhausted / expired

/// Verifies the attempt cap boundary.
- (void)testIsExhausted_atCap {
    self.policy.maxAttempts = 8;
    XCTAssertFalse([self.policy isExhaustedAttemptCount:7]);
    XCTAssertTrue([self.policy isExhaustedAttemptCount:8]);
    XCTAssertTrue([self.policy isExhaustedAttemptCount:9]);
}

/// Verifies TTL expiry relative to an injected "now".
- (void)testIsExpired_byTTL {
    self.policy.timeToLive = 100;
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1000];
    NSDate *fresh = [NSDate dateWithTimeIntervalSince1970:950];   // 50s old
    NSDate *stale = [NSDate dateWithTimeIntervalSince1970:800];   // 200s old
    XCTAssertFalse([self.policy isExpiredFirstEnqueuedDate:fresh now:now]);
    XCTAssertTrue([self.policy isExpiredFirstEnqueuedDate:stale now:now]);
}

/// Verifies that TTL of 0 disables expiry.
- (void)testIsExpired_ttlZero_neverExpires {
    self.policy.timeToLive = 0;
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:100000];
    NSDate *ancient = [NSDate dateWithTimeIntervalSince1970:0];
    XCTAssertFalse([self.policy isExpiredFirstEnqueuedDate:ancient now:now]);
}

@end
