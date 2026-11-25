//
//  PWDeliveryDelayWindow.m
//  Pushwoosh
//
//  Created by André Kis
//

#import "PWDeliveryDelayWindow.h"
#import <xlocale.h>

NSString *const kPWDeliveryDelayPayloadKey = @"pw_delivery_delay";
NSTimeInterval const kPWDeliveryDelayMaxWindow = 300;

static NSString *const kPWDeliveryDelayDecimalPattern = @"\\A[+-]?(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?\\z";

static double (^sUnitRandomProvider)(void) = nil;

@implementation PWDeliveryDelayWindow

+ (NSTimeInterval)windowFromUserInfo:(nullable NSDictionary *)userInfo {
    id value = userInfo[kPWDeliveryDelayPayloadKey];
    double rawValue;

    if ([self isBooleanValue:value]) {
        return 0;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        rawValue = [(NSNumber *)value doubleValue];
    } else if ([value isKindOfClass:[NSString class]]) {
        rawValue = [self secondsFromString:(NSString *)value];
    } else {
        return 0;
    }

    if (!isfinite(rawValue)) {
        return 0;
    }

    NSTimeInterval window = trunc(rawValue);
    if (window <= 0) {
        return 0;
    }
    return MIN(window, kPWDeliveryDelayMaxWindow);
}

/// Reads the string as Android does: trimmed of characters up to U+0020, then a plain decimal number in ASCII
/// digits (no hex, type suffix, "inf" or "nan"), else NaN. A literal too large for a double keeps its sign at the
/// largest double, so a positive one caps at the maximum and a negative one is no window.
+ (double)secondsFromString:(NSString *)string {
    static NSCharacterSet *trimmedCharacters;
    static NSRegularExpression *decimalNumber;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        trimmedCharacters = [NSCharacterSet characterSetWithRange:NSMakeRange(0, 0x21)];
        decimalNumber = [NSRegularExpression regularExpressionWithPattern:kPWDeliveryDelayDecimalPattern options:0 error:nil];
    });

    NSString *text = [string stringByTrimmingCharactersInSet:trimmedCharacters];
    if ([decimalNumber numberOfMatchesInString:text options:0 range:NSMakeRange(0, text.length)] == 0) {
        return NAN;
    }
    double seconds = strtod_l(text.UTF8String, NULL, NULL);
    return isinf(seconds) ? copysign(DBL_MAX, seconds) : seconds;
}

/// A JSON `true`/`false` arrives as an NSNumber of 1 or 0, which would otherwise read as a window.
+ (BOOL)isBooleanValue:(id)value {
    return value != nil && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

+ (NSTimeInterval)delayWithinWindow:(NSTimeInterval)window {
    double unit = sUnitRandomProvider ? sUnitRandomProvider() : (double)arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX;
    return window * unit;
}

#if DEBUG
+ (void)setUnitRandomProvider:(nullable double (^)(void))provider {
    sUnitRandomProvider = [provider copy];
}
#endif

@end
