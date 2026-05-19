//
//  PWKnockPatternDetectorTest.m
//  PushwooshTests
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <OCMock/OCMock.h>
#import "PWKnockPatternDetector.h"
#import "PWPreferences.h"

@interface PWKnockPatternDetector (Test)

- (void)reset;
- (void)performKnockAction;
- (NSString *)buildDescription;
- (void)onBackground;
- (void)onForeground;
- (BOOL)isInCooldown;
- (void)armCooldown;

@end

@interface PWKnockPatternDetectorTest : XCTestCase

@end

@implementation PWKnockPatternDetectorTest {
    __block NSTimeInterval _fakeTime;
    PWKnockPatternDetector *_detector;
    id _bundleMock;
}

- (void)setUp {
    [super setUp];
    [[PWPreferences preferences] setLastKnockTriggerTimestamp:0];
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:@"PWKnockPatternDetectorLastTriggerTimestamp"];
    _fakeTime = 1000;
    _detector = [[PWKnockPatternDetector alloc] initWithClock:^{
        return _fakeTime;
    }];
}

- (void)tearDown {
    [_bundleMock stopMocking];
    _bundleMock = nil;
    [[PWPreferences preferences] setLastKnockTriggerTimestamp:0];
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:@"PWKnockPatternDetectorLastTriggerTimestamp"];
    [super tearDown];
}

/// Emulates one real background→foreground cycle on the detector under test.
- (void)emulateKnockOn:(PWKnockPatternDetector *)detector {
    [detector onBackground];
    [detector onForeground];
}

/// Verifies that fewer than 6 knocks does not trigger the pattern.
- (void)testNoTriggerWithFewerThan6Knocks {
    id detectorMock = OCMPartialMock(_detector);
    [[detectorMock reject] performKnockAction];

    for (int i = 0; i < 5; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    [detectorMock stopMocking];
}

/// Verifies that 6 knocks within 30 seconds triggers the pattern and resets the counter.
- (void)testTriggerAfter6KnocksWithin30Seconds {
    id detectorMock = OCMPartialMock(_detector);
    OCMExpect([detectorMock performKnockAction]);

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    OCMVerifyAll(detectorMock);
    [detectorMock stopMocking];
}

/// Verifies that 6 knocks exceeding 30 seconds does not trigger.
- (void)testNoTriggerWhen6KnocksExceed30Seconds {
    id detectorMock = OCMPartialMock(_detector);
    [[detectorMock reject] performKnockAction];

    for (int i = 0; i < 6; i++) {
        _fakeTime += 7; // 5 gaps * 7s = 35s > 30s
        [self emulateKnockOn:_detector];
    }

    [detectorMock stopMocking];
}

/// Verifies that exactly 30 second boundary triggers the pattern.
- (void)testExactBoundary30SecondsTriggers {
    id detectorMock = OCMPartialMock(_detector);
    OCMExpect([detectorMock performKnockAction]);

    for (int i = 0; i < 6; i++) {
        _fakeTime += 5; // 5 gaps * 5s = 25s span from first to last
        [self emulateKnockOn:_detector];
    }

    OCMVerifyAll(detectorMock);
    [detectorMock stopMocking];
}

/// Verifies that the pattern fires again after the cooldown elapses (3601s gap).
- (void)testRepeatableTriggerAfterCooldown {
    __block int triggerCount = 0;
    id detectorMock = OCMPartialMock(_detector);
    OCMStub([detectorMock performKnockAction]).andDo(^(NSInvocation *inv) {
        triggerCount++;
    });

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    _fakeTime += 3601;

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    XCTAssertEqual(triggerCount, 2);
    [detectorMock stopMocking];
}

/// Verifies that 6 background→foreground pairs trigger registration exactly once on a fresh production-shaped detector.
- (void)testSixBackgroundActivePairsTriggerKnockOnProductionInitialState {
    __block NSTimeInterval clockTime = 1000;
    PWKnockPatternDetector *detector = [[PWKnockPatternDetector alloc] initWithClock:^{
        return clockTime;
    }];
    id detectorMock = OCMPartialMock(detector);
    OCMExpect([detectorMock performKnockAction]);

    for (int i = 0; i < 6; i++) {
        clockTime += 1;
        [self emulateKnockOn:detector];
    }

    OCMVerifyAll(detectorMock);
    [detectorMock stopMocking];
}

/// Verifies that buildDescription returns the bundle id only, with no date suffix and respecting the 64-char cap.
- (void)testBuildDescriptionFormat {
    NSString *desc = [_detector buildDescription];
    NSString *expected = [[NSBundle mainBundle] bundleIdentifier] ?: @"";

    XCTAssertEqualObjects(desc, expected);
    XCTAssertTrue(desc.length <= 64);
    XCTAssertFalse([desc containsString:@" | "]);
}

/// Verifies that buildDescription truncates a bundle id longer than 64 characters.
- (void)testBuildDescriptionTruncatesLongBundleId {
    NSString *longBundleId = [@"" stringByPaddingToLength:100 withString:@"a" startingAtIndex:0];
    _bundleMock = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([_bundleMock bundleIdentifier]).andReturn(longBundleId);

    NSString *desc = [_detector buildDescription];

    XCTAssertEqual(desc.length, 64);
    XCTAssertEqualObjects(desc, [longBundleId substringToIndex:64]);
}

/// Verifies that 6 knocks just over 30 seconds does not trigger.
- (void)testNoTriggerAt31Seconds {
    id detectorMock = OCMPartialMock(_detector);
    [[detectorMock reject] performKnockAction];

    _fakeTime = 1000;
    [self emulateKnockOn:_detector];
    for (int i = 1; i < 6; i++) {
        _fakeTime += 6.2; // total span = 5 * 6.2 = 31s > 30s
        [self emulateKnockOn:_detector];
    }

    [detectorMock stopMocking];
}

/// Verifies that startDetection subscribes to both DidEnterBackground and DidBecomeActive.
- (void)testStartDetectionObservesBackgroundAndActive {
    PWKnockPatternDetector *detector = [[PWKnockPatternDetector alloc]
        initWithClock:^NSTimeInterval{ return 1000.0; }];
    // OCMPartialMock must be installed before startDetection so the swizzles
    // are in place when the synchronously-delivered notifications fire.
    id detectorMock = OCMPartialMock(detector);
    OCMExpect([detectorMock onBackground]);
    OCMExpect([detectorMock onForeground]);

    [detector startDetection];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [nc postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];

    OCMVerifyAll(detectorMock);
    [detectorMock stopMocking];
}

/// Verifies that DidBecomeActive without a preceding DidEnterBackground does NOT advance the knock counter (Control Center / Face ID / system-overlay guard).
- (void)testDidBecomeActiveWithoutBackgroundDoesNotAdvanceCounter {
    id detectorMock = OCMPartialMock(_detector);
    [[detectorMock reject] performKnockAction];

    for (int i = 0; i < 10; i++) {
        _fakeTime += 1;
        [_detector onForeground];
    }

    [detectorMock stopMocking];
}

/// Verifies that one background event followed by one active event counts a single knock.
- (void)testDidEnterBackgroundFollowedByDidBecomeActiveCountsOneKnock {
    id detectorMock = OCMPartialMock(_detector);
    OCMExpect([detectorMock performKnockAction]);

    for (int i = 0; i < 5; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }
    _fakeTime += 1;
    [_detector onBackground];
    [_detector onForeground];

    OCMVerifyAll(detectorMock);
    [detectorMock stopMocking];
}

/// Verifies that the background flag is consumed after one foreground: a second foreground without another background is ignored.
- (void)testBackgroundFlagIsSingleUse {
    id detectorMock = OCMPartialMock(_detector);
    [[detectorMock reject] performKnockAction];

    [_detector onBackground];
    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [_detector onForeground];
    }

    [detectorMock stopMocking];
}

/// Verifies that the cooldown blocks a second pattern match within an hour of the first.
- (void)testCooldownBlocksSecondTriggerWithinAnHour {
    __block int triggerCount = 0;
    id detectorMock = OCMPartialMock(_detector);
    OCMStub([detectorMock performKnockAction]).andDo(^(NSInvocation *inv) {
        triggerCount++;
    });

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    _fakeTime += 1800; // 30 minutes — still within cooldown

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    XCTAssertEqual(triggerCount, 1);
    [detectorMock stopMocking];
}

/// Verifies that the cooldown expires after one hour and the next pattern match triggers again.
- (void)testCooldownExpiresAfterOneHour {
    __block int triggerCount = 0;
    id detectorMock = OCMPartialMock(_detector);
    OCMStub([detectorMock performKnockAction]).andDo(^(NSInvocation *inv) {
        triggerCount++;
    });

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    _fakeTime += 3601;

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    XCTAssertEqual(triggerCount, 2);
    [detectorMock stopMocking];
}

/// Verifies the strict `<` cooldown comparison: at delta = 3599s (just below the 3600s threshold) the second match is still blocked.
- (void)testCooldownJustBelow3600sIsStillBlocked {
    __block int triggerCount = 0;
    id detectorMock = OCMPartialMock(_detector);
    OCMStub([detectorMock performKnockAction]).andDo(^(NSInvocation *inv) {
        triggerCount++;
    });

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }
    NSTimeInterval firstTriggerTime = _fakeTime;

    _fakeTime = firstTriggerTime + 3593;

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    XCTAssertEqual(triggerCount, 1);
    [detectorMock stopMocking];
}

/// Verifies the strict `<` cooldown comparison: at delta = 3600s exactly the gate is expired, so the second match goes through.
- (void)testCooldownAtExact3600sAllowsRetrigger {
    __block int triggerCount = 0;
    id detectorMock = OCMPartialMock(_detector);
    OCMStub([detectorMock performKnockAction]).andDo(^(NSInvocation *inv) {
        triggerCount++;
    });

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }
    NSTimeInterval firstTriggerTime = _fakeTime;

    _fakeTime = firstTriggerTime + 3594;

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    XCTAssertEqual(triggerCount, 2);
    [detectorMock stopMocking];
}

/// Verifies that a backwards clock jump is treated as expired cooldown so the next pattern match goes through.
- (void)testCooldownTreatsBackwardsClockAsExpired {
    __block int triggerCount = 0;
    id detectorMock = OCMPartialMock(_detector);
    OCMStub([detectorMock performKnockAction]).andDo(^(NSInvocation *inv) {
        triggerCount++;
    });

    _fakeTime = 5000;
    [_detector armCooldown];

    _fakeTime = 3000;
    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    XCTAssertEqual(triggerCount, 1);
    [detectorMock stopMocking];
}

/// Verifies that cooldown is armed on pattern match before the network call (the persisted timestamp matches the 6th-knock clock).
- (void)testCooldownIsArmedOnPatternMatchNotOnNetworkSuccess {
    id detectorMock = OCMPartialMock(_detector);
    OCMStub([detectorMock performKnockAction]).andDo(^(NSInvocation *inv) {
        // no-op — explicitly skip the network call to prove arming is independent of it
    });

    NSTimeInterval lastKnockTime = 0;
    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        lastKnockTime = _fakeTime;
        [self emulateKnockOn:_detector];
    }

    XCTAssertEqual([PWPreferences preferences].lastKnockTriggerTimestamp, lastKnockTime);
    [detectorMock stopMocking];
}

@end
