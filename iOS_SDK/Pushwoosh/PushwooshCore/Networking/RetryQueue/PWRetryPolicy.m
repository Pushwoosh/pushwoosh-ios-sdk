/*
 *  PWRetryPolicy.m
 *  Pushwoosh
 *
 *  Created by André Kis
 */

#import "PWRetryPolicy.h"
#import "PWUtils.h"

@implementation PWRetryPolicy

- (instancetype)init {
    if (self = [super init]) {
        _baseDelay = 25.0;
        _maxDelay = 6 * 60 * 60;
        _minDelay = 2.0;
        _jitterFraction = 0.25;
        _maxAttempts = 3;
        _timeToLive = 3 * 24 * 60 * 60;
        _inFlightTimeout = 120.0;
    }
    return self;
}

- (BOOL)shouldRetryStatusCode:(NSInteger)statusCode error:(NSError *)error {
    switch (statusCode) {
        case 408:
        case 429:
        case 500:
        case 502:
        case 503:
        case 504:
            return YES;
        default:
            break;
    }

    if (statusCode != 0) {
        return NO;
    }

    if (error && [error.domain isEqualToString:NSURLErrorDomain]) {
        switch (error.code) {
            case NSURLErrorTimedOut:
            case NSURLErrorCannotConnectToHost:
            case NSURLErrorNetworkConnectionLost:
            case NSURLErrorNotConnectedToInternet:
            case NSURLErrorDNSLookupFailed:
            case NSURLErrorInternationalRoamingOff:
            case NSURLErrorDataNotAllowed:
                return YES;
            default:
                return NO;
        }
    }

    if (error && [error.domain isEqualToString:PWErrorDomain] &&
        (error.code == PWErrorCommunicationDisabled || error.code == PWErrorRequestNotReady)) {
        return YES;
    }

    return NO;
}

- (NSTimeInterval)delayForAttempt:(NSUInteger)attemptCount {
    double value = _baseDelay;
    for (NSUInteger i = 0; i <= attemptCount; i++) {
        double growth = (value > 0) ? log2(value) : 1.0;
        if (growth < 1.0) {
            growth = 1.0;
        }
        value = value * growth;
    }
    if (value > _maxDelay) {
        value = _maxDelay;
    }

    double unit = (double)arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX;
    double jitter = value * _jitterFraction * (unit * 2.0 - 1.0);
    double delay = value + jitter;

    if (delay < _minDelay) {
        delay = _minDelay;
    }
    if (delay > _maxDelay) {
        delay = _maxDelay;
    }
    return delay;
}

- (BOOL)isExhaustedAttemptCount:(NSUInteger)attemptCount {
    return attemptCount >= _maxAttempts;
}

- (BOOL)isExpiredFirstEnqueuedDate:(NSDate *)firstEnqueuedDate now:(NSDate *)now {
    if (_timeToLive <= 0) {
        return NO;
    }
    NSTimeInterval age = [now timeIntervalSinceDate:firstEnqueuedDate];
    return age < 0 || age > _timeToLive;
}

@end
