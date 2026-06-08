//
//  PWRequest.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PWPreferences.h>
#import <PushwooshCore/NSDictionary+PWDictUtils.h>

@interface PWRequest : NSObject

@property (nonatomic, assign) NSInteger httpCode;
@property (nonatomic) BOOL cacheable;
@property (nonatomic) BOOL usePreviousHWID;
@property (nonatomic) int startTime;

/// Retry attempt number for requests replayed from the offline retry queue
/// (`1` for the first replay, incrementing per attempt). `0` for a first-time
/// send. When non-zero it is surfaced to the backend via the `X-Retry-Count`
/// HTTP header.
@property (nonatomic, assign) NSInteger retryCount;

- (NSString *)uid;
- (NSString *)methodName;
- (NSDictionary *)requestDictionary;

/// Stable, unique-per-instance identifier used as the dedup / retry-tracking key
/// in the offline retry queue.
///
/// Lazily generated as a UUID on first access and snapshotted into `PWRetryEntry`,
/// so it survives archiving and app relaunches. It replaces the previous
/// `self.hash` derivation, which was the object pointer address — unstable and
/// prone to collisions between distinct requests once a freed address was reused.
///
/// Kept as a readonly method on the public surface (identical to the released
/// API, so the Swift bridge shape is unchanged) — the internal setter lives in
/// a private category, used only when snapshotting a request for retry.
- (NSString *)requestIdentifier;

- (NSString *)baseUrl;
- (BOOL)shouldWrapRequest;

- (NSMutableDictionary *)baseDictionary;
- (void)parseResponse:(NSDictionary *)response;

@end
