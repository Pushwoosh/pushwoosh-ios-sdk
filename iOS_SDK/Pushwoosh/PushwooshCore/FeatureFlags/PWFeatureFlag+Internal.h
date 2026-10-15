//  PWFeatureFlag+Internal.h
//  Created by André Kis

#import <PushwooshCore/PWFeatureFlag.h>

#if TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

@interface PWFeatureFlag (Internal)

/// Flags of a `flags` JSON object by key, or `nil` when any flag is malformed.
+ (nullable NSDictionary<NSString *, PWFeatureFlag *> *)flagsWithJSONObject:(id)flags;

/// Same key, `enabled`, `ruleId` and properties, a JSON boolean never equals a number.
- (BOOL)hasSameValueAsFlag:(PWFeatureFlag *)flag;

@end

NS_ASSUME_NONNULL_END

#endif
