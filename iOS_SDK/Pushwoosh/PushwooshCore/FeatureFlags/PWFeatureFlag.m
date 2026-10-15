//  PWFeatureFlag.m
//  Created by André Kis

#import "PWFeatureFlag+Internal.h"

#if TARGET_OS_IOS

static BOOL PWIsJSONBoolean(id value) {
    return [value isKindOfClass:[NSNumber class]] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

@interface PWFeatureFlag ()

@property (nonatomic, readwrite, copy) NSString *key;
@property (nonatomic, readwrite, getter=isEnabled) BOOL enabled;
@property (nonatomic, readwrite, copy) NSString *ruleId;
@property (nonatomic, copy) NSDictionary<NSString *, id> *properties;

@end

@implementation PWFeatureFlag

+ (NSDictionary<NSString *, PWFeatureFlag *> *)flagsWithJSONObject:(id)flags {
    if (![flags isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSMutableDictionary<NSString *, PWFeatureFlag *> *result = [NSMutableDictionary new];
    for (id key in flags) {
        PWFeatureFlag *flag = [self flagWithKey:key JSONObject:flags[key]];
        if (!flag) {
            return nil;
        }
        result[key] = flag;
    }
    return [result copy];
}

+ (PWFeatureFlag *)flagWithKey:(id)key JSONObject:(id)json {
    if (![key isKindOfClass:[NSString class]] || ![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    id enabled = json[@"enabled"];
    if (!PWIsJSONBoolean(enabled)) {
        return nil;
    }

    id ruleId = json[@"rule_id"];
    id properties = json[@"properties"];

    PWFeatureFlag *flag = [[self alloc] initInternal];
    flag.key = key;
    flag.enabled = [enabled boolValue];
    flag.ruleId = [ruleId isKindOfClass:[NSString class]] ? ruleId : @"";
    flag.properties = [properties isKindOfClass:[NSDictionary class]] ? properties : @{};
    return flag;
}

- (instancetype)initInternal {
    return [super init];
}

- (NSString *)stringForProperty:(NSString *)property defaultValue:(NSString *)defaultValue {
    id value = _properties[property];
    return [value isKindOfClass:[NSString class]] ? value : defaultValue;
}

- (double)numberForProperty:(NSString *)property defaultValue:(double)defaultValue {
    id value = _properties[property];
    return [value isKindOfClass:[NSNumber class]] && !PWIsJSONBoolean(value) ? [value doubleValue] : defaultValue;
}

- (BOOL)boolForProperty:(NSString *)property defaultValue:(BOOL)defaultValue {
    id value = _properties[property];
    return PWIsJSONBoolean(value) ? [value boolValue] : defaultValue;
}

- (NSDictionary<NSString *, id> *)jsonObjectForProperty:(NSString *)property {
    id value = _properties[property];
    return [value isKindOfClass:[NSDictionary class]] ? [value copy] : nil;
}

- (NSArray *)jsonArrayForProperty:(NSString *)property {
    id value = _properties[property];
    return [value isKindOfClass:[NSArray class]] ? [value copy] : nil;
}

- (BOOL)hasSameValueAsFlag:(PWFeatureFlag *)flag {
    return _enabled == flag.enabled
        && [_key isEqualToString:flag.key]
        && [_ruleId isEqualToString:flag.ruleId]
        && [[self sortedJSONOfProperties] isEqualToData:[flag sortedJSONOfProperties]];
}

- (NSData *)sortedJSONOfProperties {
    return [NSJSONSerialization dataWithJSONObject:_properties options:NSJSONWritingSortedKeys error:nil];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PWFeatureFlag key=%@ enabled=%d ruleId=%@>", _key, _enabled, _ruleId];
}

@end

#endif
