//  PWMessageSilentPushTest.m
//  Created by André Kis on 06.10.26.

#import <XCTest/XCTest.h>
#import "PWMessage+Internal.h"

@interface PWMessageSilentPushTest : XCTestCase
@end

@implementation PWMessageSilentPushTest

/// Verifies the one rule every open/received decision now shares: a push is silent only when the
/// content-available flag is truthy and there is nothing to show.
- (void)testFlagWithoutAlertIsSilent {
    XCTAssertTrue(([PWMessage isSilentPush:@{ @"aps" : @{ @"content-available" : @1 }, @"p" : @"h4", @"pw_msg" : @"1" }]));
    XCTAssertTrue(([PWMessage isSilentPush:@{ @"aps" : @{ @"content-available" : @"1" }, @"p" : @"h4", @"pw_msg" : @"1" }]));
    XCTAssertTrue(([PWMessage isSilentPush:@{ @"aps" : @{ @"content-available" : @1 }, @"l" : @"pwdemo://x", @"p" : @"h4", @"pw_msg" : @"1" }]));
}

/// Verifies that a visible push keeps being visible whatever form the flag and the alert take.
- (void)testFlagWithAlertIsVisible {
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @"hi", @"content-available" : @"1", @"mutable-content" : @1, @"sound" : @"default" }, @"p" : @"h1", @"pw_msg" : @"1" }]));
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @"hi", @"content-available" : @1 }, @"p" : @"h2", @"pw_msg" : @"1" }]));
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @{ @"title" : @"t", @"body" : @"b" }, @"content-available" : @"1" }, @"p" : @"h3", @"pw_msg" : @"1" }]));
}

/// Verifies that a falsy flag is an ordinary push, in every spelling the API lets through.
- (void)testFalsyFlagIsNotSilent {
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @"hi", @"content-available" : @"0" } }]));
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @"hi", @"content-available" : @0 } }]));
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @"hi", @"content-available" : @NO } }]));
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @"hi", @"content-available" : @"false" } }]));
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"content-available" : @0 } }]));
}

/// Verifies that a push without the flag is never silent, with or without an alert.
- (void)testNoFlagIsNotSilent {
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @"hi", @"mutable-content" : @1 }, @"p" : @"h5", @"pw_msg" : @"1" }]));
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"badge" : @1 } }]));
    XCTAssertFalse(([PWMessage isSilentPush:@{}]));
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @"not a dictionary" }]));
}

/// Verifies that an alert that cannot show anything does not turn a silent push into a visible one.
- (void)testEmptyAlertIsSilent {
    XCTAssertTrue(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @"", @"content-available" : @1 } }]));
    XCTAssertTrue(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @{}, @"content-available" : @1 } }]));
}

/// Verifies that a flag of an unexpected type is ignored instead of crashing on boolValue.
- (void)testFlagOfUnexpectedTypeIsNotSilent {
    XCTAssertNoThrow(([PWMessage isSilentPush:@{ @"aps" : @{ @"content-available" : [NSNull null] } }]));
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"content-available" : [NSNull null] } }]));
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"content-available" : @[ @1 ] } }]));
}

/// Verifies that an alert of an unexpected type is treated as something to show, so a malformed
/// visible payload keeps counting opens instead of silently dropping them.
- (void)testAlertOfUnexpectedTypeIsVisible {
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @123, @"content-available" : @1 } }]));
    XCTAssertFalse(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : @[ @"x" ], @"content-available" : @1 } }]));
    XCTAssertTrue(([PWMessage isSilentPush:@{ @"aps" : @{ @"alert" : [NSNull null], @"content-available" : @1 } }]));
}

@end
