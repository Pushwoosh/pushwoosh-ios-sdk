//
//  PWConfig.m
//  PushwooshTests
//
//  Created by Fectum on 20/09/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PWConfig.h"
#import "PWBundleMock.h"

@interface PWConfigTest : XCTestCase

@property (nonatomic) PWConfig *config;

@end

@implementation PWConfigTest

- (void)setUp {
    [super setUp];
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSendPushStatIfAlertsDisabledNo {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.sendPushStatIfAlertsDisabled = NO;

    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    BOOL result = _config.sendPushStatIfAlertsDisabled;
    XCTAssertEqual(NO, result);
}

- (void)testSendPushStatIfAlertsDisabledYes {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.sendPushStatIfAlertsDisabled = YES;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    BOOL result = _config.sendPushStatIfAlertsDisabled;
    XCTAssertEqual(YES, result);
}

- (void)testSendPurchaseTrackingEnabled {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.sendPurchaseTrackingEnabled = YES;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    BOOL result = _config.sendPurchaseTrackingEnabled;
    XCTAssertEqual(YES, result);
}

/// Verifies that idle tracking is disabled when no timeout key is configured (Android parity).
- (void)testIdleTimeoutKeyAbsentDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

/// Verifies that idle timeout uses configured value when above minimum.
- (void)testIdleTimeoutUsesConfiguredValue {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @60;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(60, _config.idleTimeoutSeconds);
}

/// Verifies that idle timeout below 30s is clamped to the 30s minimum.
- (void)testIdleTimeoutBelowMinimumIsClamped {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @10;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.idleTimeoutSeconds);
}

/// Verifies that explicit zero disables idle tracking entirely (Android parity).
- (void)testIdleTimeoutZeroDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @0;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

/// Verifies that negative values disable idle tracking (Android parity).
- (void)testIdleTimeoutNegativeDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @(-5);
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

/// Verifies that value of 1 is clamped to the 30s minimum with a warning.
- (void)testIdleTimeoutOneIsClamped {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @1;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.idleTimeoutSeconds);
}

/// Verifies that value of 5 is clamped to the 30s minimum (below-minimum path).
- (void)testIdleTimeoutFiveIsClamped {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @5;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.idleTimeoutSeconds);
}

/// Verifies that value of 29 (just below boundary) is clamped to the 30s minimum.
- (void)testIdleTimeoutTwentyNineIsClamped {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @29;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.idleTimeoutSeconds);
}

/// Verifies that value of exactly 30 passes through without clamping.
- (void)testIdleTimeoutThirtyPassesThrough {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @30;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.idleTimeoutSeconds);
}

/// Verifies that value of -1 disables idle tracking entirely.
- (void)testIdleTimeoutMinusOneDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @(-1);
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

/// Verifies that a large negative value disables idle tracking.
- (void)testIdleTimeoutLargeNegativeDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @(-9999);
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

/// Verifies that idle timeout is forced to 0 when lifecycle events collection is disabled.
- (void)testIdleTimeoutIsZeroWhenCollectingEventsDisabled {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.allowCollectingEventsSet = YES;
    bundleMock.allowCollectingEvents = NO;
    bundleMock.idleTimeoutSeconds = @60;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

@end
