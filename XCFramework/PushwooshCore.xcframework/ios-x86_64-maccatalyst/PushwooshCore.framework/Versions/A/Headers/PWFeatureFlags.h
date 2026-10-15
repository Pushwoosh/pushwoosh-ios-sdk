//  PWFeatureFlags.h
//  Created by André Kis

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS

#import <PushwooshCore/PWFeatureFlag.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain of a failed refresh. `code` is the HTTP status: `0` when no HTTP response was received
/// or the refresh failed locally, `200` when the response could not be used.
FOUNDATION_EXPORT NSErrorDomain const PWFeatureFlagsErrorDomain;

/// Receives `featureFlagsDidUpdate` on the main thread after a refresh changed what `get` returns.
@protocol PWFeatureFlagsUpdateListener <NSObject>

/// Called when a refresh added or removed a flag or changed its `enabled`, `ruleId` or properties.
/// Not called when the response matched the cache, on errors or when a user change cleared the cache.
- (void)featureFlagsDidUpdate;

@end

/// Feature flags evaluated by Pushwoosh for this device and user, `Pushwoosh.configure.featureFlags`.
/// Refresh triggers, cache lifetime and examples: `+[PushwooshConfig featureFlags]`. Available on iOS only.
@interface PWFeatureFlags : NSObject

/// Cached flag, or `nil` when there is no cache younger than 24 hours for the current user and app code
/// or no such flag. Synchronous, never sends a request.
- (nullable PWFeatureFlag *)flagForKey:(NSString *)key NS_SWIFT_NAME(get(_:));

/// `isEnabled` of the cached flag, or `defaultValue` when `get` returns `nil`.
- (BOOL)isEnabled:(NSString *)key defaultValue:(BOOL)defaultValue NS_SWIFT_NAME(isEnabled(_:default:));

/// Requests fresh flags and calls `completion` on the main thread with `nil` or a `PWFeatureFlagsErrorDomain` error,
/// keeping the cache on failure. Joins a request in flight; within 5 minutes of the last one a valid cache answers.
- (void)refreshWithCompletion:(nullable void (^)(NSError * _Nullable error))completion NS_SWIFT_NAME(refresh(completion:));

/// Adds a listener held weakly, keep a strong reference to it. Adding the same listener again has no effect.
- (void)addUpdateListener:(id<PWFeatureFlagsUpdateListener>)listener NS_SWIFT_NAME(addUpdateListener(_:));

/// Removes a listener added with `addUpdateListener`; an unknown listener is ignored.
- (void)removeUpdateListener:(id<PWFeatureFlagsUpdateListener>)listener NS_SWIFT_NAME(removeUpdateListener(_:));

/// Posts `PW_FeatureFlagImpression` (`flag_key`, `rule_id`, `enabled`) for the cached flag once per session and flag value,
/// sends it again after a failed post, does nothing without a cached flag. Log both branches: the disabled one is the control group.
- (void)logImpression:(NSString *)key NS_SWIFT_NAME(logImpression(_:));

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#endif
