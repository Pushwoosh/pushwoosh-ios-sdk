//  PWFeatureFlags.m
//  Created by André Kis

#import "PWFeatureFlags.h"

#if TARGET_OS_IOS

#import "PWFeatureFlagsManager.h"

NSErrorDomain const PWFeatureFlagsErrorDomain = @"com.pushwoosh.featureflags";

@implementation PWFeatureFlags

+ (PWFeatureFlags *)sharedFeatureFlags {
    static PWFeatureFlags *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] initShared];
    });
    return instance;
}

- (instancetype)initShared {
    return [super init];
}

- (PWFeatureFlag *)flagForKey:(NSString *)key {
    return [[PWFeatureFlagsManager sharedManager] flagForKey:key];
}

- (BOOL)isEnabled:(NSString *)key defaultValue:(BOOL)defaultValue {
    PWFeatureFlag *flag = [self flagForKey:key];
    return flag ? flag.isEnabled : defaultValue;
}

- (void)refreshWithCompletion:(void (^)(NSError *))completion {
    [[PWFeatureFlagsManager sharedManager] refreshWithCompletion:completion];
}

- (void)addUpdateListener:(id<PWFeatureFlagsUpdateListener>)listener {
    [[PWFeatureFlagsManager sharedManager] addUpdateListener:listener];
}

- (void)removeUpdateListener:(id<PWFeatureFlagsUpdateListener>)listener {
    [[PWFeatureFlagsManager sharedManager] removeUpdateListener:listener];
}

- (void)logImpression:(NSString *)key {
    [[PWFeatureFlagsManager sharedManager] logImpression:key];
}

@end

#endif
