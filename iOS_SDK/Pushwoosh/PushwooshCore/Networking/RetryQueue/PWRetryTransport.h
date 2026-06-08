//
//  PWRetryTransport.h
//  Pushwoosh
//
//  Created by André Kis
//

#import <Foundation/Foundation.h>

@class PWRetryEntry;

NS_ASSUME_NONNULL_BEGIN

/// Abstraction the retry queue uses to actually send an entry. The production
/// implementation (`PWRequestManager`) rebuilds a request from the entry and sends
/// it over REST only (never gRPC), so every retry passes the server-communication
/// (GDPR) gate and takes a single, predictable transport path. Tests substitute a fake.
@protocol PWRetryTransport <NSObject>

/// Send one queued entry. `completion` is invoked on an arbitrary queue:
/// `error == nil` means the server accepted it (remove from queue). On failure,
/// `statusCode` is the HTTP status (0 for a transport-level error) and `error` is
/// non-nil; `PWRetryPolicy` uses both to classify the failure as transient
/// (reschedule) or permanent (drop).
- (void)sendRetryEntry:(PWRetryEntry *)entry
            completion:(void (^)(NSInteger statusCode, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
