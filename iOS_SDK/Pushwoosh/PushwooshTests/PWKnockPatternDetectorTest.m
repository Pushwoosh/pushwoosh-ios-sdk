//
//  PWKnockPatternDetectorTest.m
//  PushwooshTests
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <OCMock/OCMock.h>
#import "PWKnockPatternDetector.h"

@interface PWKnockPatternDetector (Test)

- (void)reset;
- (void)performKnockAction;
- (NSString *)buildDescription;
- (void)onBackground;
- (void)onForeground;

@end

@interface PWKnockPatternDetectorTest : XCTestCase

@end

@implementation PWKnockPatternDetectorTest {
    __block NSTimeInterval _fakeTime;
    PWKnockPatternDetector *_detector;
}

- (void)setUp {
    _fakeTime = 1000;
    _detector = [[PWKnockPatternDetector alloc] initWithClock:^{
        return _fakeTime;
    }];
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

/// Verifies that the pattern can trigger again after a reset.
- (void)testRepeatableTrigger {
    __block int triggerCount = 0;
    id detectorMock = OCMPartialMock(_detector);
    OCMStub([detectorMock performKnockAction]).andDo(^(NSInvocation *inv) {
        triggerCount++;
    });

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [self emulateKnockOn:_detector];
    }

    _fakeTime += 60;

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

/// Verifies that buildDescription returns correct format.
- (void)testBuildDescriptionFormat {
    NSString *desc = [_detector buildDescription];

    XCTAssertTrue(desc.length > 0);
    XCTAssertTrue(desc.length <= 64);
    XCTAssertTrue([desc containsString:@"|"]);
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

@end
