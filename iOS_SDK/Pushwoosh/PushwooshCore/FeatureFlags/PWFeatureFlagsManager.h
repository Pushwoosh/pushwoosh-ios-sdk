//  PWFeatureFlagsManager.h
//  Created by André Kis

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS

#import <PushwooshCore/PWFeatureFlags.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWFeatureFlagsManager : NSObject

+ (instancetype)sharedManager;

/// Subscribes to app lifecycle for automatic refreshes; called from the app launch hook, repeated calls are no-ops.
- (void)start;

/// Starts like `-start` when the SDK initializes lazily after launch; an app that is already active begins its session at once.
- (void)startAfterLaunch;

/// Called after a successful APNs device registration.
- (void)deviceRegistered;

/// Called after the server accepted a user id.
- (void)userIdUpdated;

/// Called after a rejected user id was rolled back.
- (void)userIdUpdateFailed;

- (void)addUpdateListener:(id<PWFeatureFlagsUpdateListener>)listener;

- (void)removeUpdateListener:(id<PWFeatureFlagsUpdateListener>)listener;

- (nullable PWFeatureFlag *)flagForKey:(NSString *)key;

- (void)refreshWithCompletion:(nullable void (^)(NSError * _Nullable error))completion;

- (void)logImpression:(NSString *)key;

@end

@interface PWFeatureFlags (Internal)

+ (PWFeatureFlags *)sharedFeatureFlags;

@end

NS_ASSUME_NONNULL_END

#endif
