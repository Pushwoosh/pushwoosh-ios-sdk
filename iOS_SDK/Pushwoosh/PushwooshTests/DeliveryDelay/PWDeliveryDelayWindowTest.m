//
//  PWDeliveryDelayWindowTest.m
//  PushwooshTests
//
//  Created by André Kis
//

#import <XCTest/XCTest.h>
#import "PWDeliveryDelayWindow.h"
#import "PWDeliveryDelayTestSeams.h"

@interface PWDeliveryDelayWindowTest : XCTestCase
@end

@implementation PWDeliveryDelayWindowTest

- (void)tearDown {
    [PWDeliveryDelayWindow setUnitRandomProvider:nil];
    [super tearDown];
}

/// Verifies a missing, empty, non-numeric, trailing-garbage, zero or negative value yields no window.
- (void)testWindowAbsentForInvalidValues {
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:nil], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @""}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"abc"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"60abc"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"0"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"-5"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @(-5)}], 0);
}

/// Verifies "60" as a string and 60 as a number both yield a 60 second window.
- (void)testWindowAcceptsStringAndNumber {
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"60"}], 60);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @(60)}], 60);
}

/// Verifies the plain decimal forms Android accepts: exponent, explicit sign, trailing dot, ASCII padding, a short window.
- (void)testWindowAcceptsPlainDecimalForms {
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"6e1"}], 60);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"+60"}], 60);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"60."}], 60);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @" 60 "}], 60);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"2"}], 2);
}

/// Verifies a value padded with ASCII control characters is read like on Android, which trims everything up to U+0020.
- (void)testWindowTrimsAsciiControlCharacters {
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"\x1f" @"60"}], 60);
    NSString *nulPadded = [NSString stringWithFormat:@"%C60%C", (unichar)0, (unichar)0];
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: nulPadded}], 60);
}

/// Verifies non-ASCII spaces around the number and non-ASCII digits yield no window, as on Android.
- (void)testWindowAbsentForNonAsciiSpacesOrDigits {
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"\u00a060"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"60\u00a0"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"\u300060"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"60\u2028"}], 0);
    NSString *nextLinePadded = [NSString stringWithFormat:@"%C60", (unichar)0x85];
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: nextLinePadded}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"\u0666\u0660"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"\uff16\uff10"}], 0);
}

/// Verifies number syntax beyond a plain decimal (type suffix, hex) yields no window, as on Android.
- (void)testWindowAbsentForSuffixedOrHexLiterals {
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"60d"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"60D"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"60f"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"60F"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"1e2d"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"0x1p8"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"0X1.8P5"}], 0);
}

/// Verifies a fractional value is truncated to whole seconds.
- (void)testWindowTruncatesFraction {
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"30.5"}], 30);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @(30.9)}], 30);
}

/// Verifies a window above the cap is clamped to 300 seconds.
- (void)testWindowClampsToMaximum {
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @(1000)}], 300);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"1000"}], 300);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"99999999999999999999"}], 300);
}

/// Verifies a positive decimal literal too large for a double is capped at 300 seconds, as on Android.
- (void)testWindowClampsPositiveLiteralOverflowingDoubleToMaximum {
    NSString *fourHundredNines = [@"" stringByPaddingToLength:400 withString:@"9" startingAtIndex:0];
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: fourHundredNines}], 300);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"1e999"}], 300);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"1e400"}], 300);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"+1e999"}], 300);
}

/// Verifies a negative decimal literal too large for a double yields no window, as on Android.
- (void)testWindowAbsentForNegativeLiteralOverflowingDouble {
    NSString *fourHundredNines = [@"" stringByPaddingToLength:400 withString:@"9" startingAtIndex:0];
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: [@"-" stringByAppendingString:fourHundredNines]}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"-1e999"}], 0);
}

/// Verifies an infinity or NaN literal or number yields no window instead of the full 300 seconds.
- (void)testWindowAbsentForNonFiniteValues {
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"inf"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"infinity"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"Infinity"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"-Infinity"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"-inf"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"nan"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @"NaN"}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @(INFINITY)}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @(-INFINITY)}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @(NAN)}], 0);
}

/// Verifies a JSON boolean yields no window rather than a one or zero second one.
- (void)testWindowAbsentForBooleanValues {
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @(YES)}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @(NO)}], 0);

    NSData *payload = [@"{\"pw_delivery_delay\":true}" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *userInfo = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:userInfo], 0);
}

/// Verifies a non-scalar value yields no window instead of crashing.
- (void)testWindowAbsentForNonScalarValues {
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @[]}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: @{}}], 0);
    XCTAssertEqual([PWDeliveryDelayWindow windowFromUserInfo:@{kPWDeliveryDelayPayloadKey: [NSNull null]}], 0);
}

/// Verifies the random pick spans the whole window: 0.0 gives 0, 1.0 gives the window, 0.5 gives half.
- (void)testDelayFollowsUnitRandomProvider {
    [PWDeliveryDelayWindow setUnitRandomProvider:^double { return 0.0; }];
    XCTAssertEqual([PWDeliveryDelayWindow delayWithinWindow:60], 0);
    [PWDeliveryDelayWindow setUnitRandomProvider:^double { return 1.0; }];
    XCTAssertEqual([PWDeliveryDelayWindow delayWithinWindow:60], 60);
    [PWDeliveryDelayWindow setUnitRandomProvider:^double { return 0.5; }];
    XCTAssertEqual([PWDeliveryDelayWindow delayWithinWindow:60], 30);
}

@end
