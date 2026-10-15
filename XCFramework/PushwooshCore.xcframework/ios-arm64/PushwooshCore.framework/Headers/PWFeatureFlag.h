//  PWFeatureFlag.h
//  Created by André Kis

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

/// Immutable snapshot of one feature flag. Property getters return the default when the property
/// is absent or has another JSON type: a string is never read as a number, a JSON boolean never as a number.
@interface PWFeatureFlag : NSObject

/// Key of the flag.
@property (nonatomic, readonly, copy) NSString *key;

/// Whether the flag is on for this device.
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;

/// Id of the matched rule, `"default"` when no rule matched, `""` when the flag is killed.
@property (nonatomic, readonly, copy) NSString *ruleId;

/// String property, or `defaultValue` when it is absent or not a string.
- (nullable NSString *)stringForProperty:(NSString *)property defaultValue:(nullable NSString *)defaultValue NS_SWIFT_NAME(string(forProperty:default:));

/// Number property, or `defaultValue` when it is absent or not a number.
- (double)numberForProperty:(NSString *)property defaultValue:(double)defaultValue NS_SWIFT_NAME(number(forProperty:default:));

/// Boolean property, or `defaultValue` when it is absent or not a boolean.
/// Swift name is a string literal: `bool` is a stdbool macro, `NS_SWIFT_NAME` would import `_Bool(forProperty:default:)`.
- (BOOL)boolForProperty:(NSString *)property defaultValue:(BOOL)defaultValue __attribute__((swift_name("bool(forProperty:default:)")));

/// JSON object property, or `nil` when it is absent or not an object.
- (nullable NSDictionary<NSString *, id> *)jsonObjectForProperty:(NSString *)property NS_SWIFT_NAME(jsonObject(forProperty:));

/// JSON array property, or `nil` when it is absent or not an array.
- (nullable NSArray *)jsonArrayForProperty:(NSString *)property NS_SWIFT_NAME(jsonArray(forProperty:));

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#endif
