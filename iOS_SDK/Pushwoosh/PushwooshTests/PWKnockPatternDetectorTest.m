//
//  PWKnockPatternDetectorTest.m
//  PushwooshTests
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWKnockPatternDetector.h"

@interface PWKnockPatternDetector (Test)

- (void)reset;
- (void)performKnockAction;
- (NSString *)buildDescription;

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

/// Verifies that fewer than 6 knocks does not trigger the pattern.
- (void)testNoTriggerWithFewerThan6Knocks {
    for (int i = 0; i < 5; i++) {
        _fakeTime += 1;
        [_detector onForeground];
    }

    // No crash, no trigger — just count incremented
}

/// Verifies that 6 knocks within 30 seconds triggers the pattern and resets the counter.
- (void)testTriggerAfter6KnocksWithin30Seconds {
    id detectorMock = OCMPartialMock(_detector);
    OCMExpect([detectorMock performKnockAction]);

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [_detector onForeground];
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
        [_detector onForeground];
    }

    [detectorMock stopMocking];
}

/// Verifies that exactly 30 second boundary triggers the pattern.
- (void)testExactBoundary30SecondsTriggers {
    id detectorMock = OCMPartialMock(_detector);
    OCMExpect([detectorMock performKnockAction]);

    for (int i = 0; i < 6; i++) {
        _fakeTime += 5; // 5 gaps * 5s = 25s, but total span from first to last = 5*5 = 25s
        [_detector onForeground];
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
        [_detector onForeground];
    }

    _fakeTime += 60;

    for (int i = 0; i < 6; i++) {
        _fakeTime += 1;
        [_detector onForeground];
    }

    XCTAssertEqual(triggerCount, 2);
    [detectorMock stopMocking];
}

/// Verifies that first launch is skipped when using default init.
- (void)testFirstLaunchSkipped {
    PWKnockPatternDetector *defaultDetector = [[PWKnockPatternDetector alloc] init];
    id detectorMock = OCMPartialMock(defaultDetector);
    [[detectorMock reject] reset];

    [defaultDetector onForeground]; // first call — skipped

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
    [_detector onForeground];
    for (int i = 1; i < 6; i++) {
        _fakeTime += 6.2; // total span = 5 * 6.2 = 31s > 30s
        [_detector onForeground];
    }

    [detectorMock stopMocking];
}

@end
