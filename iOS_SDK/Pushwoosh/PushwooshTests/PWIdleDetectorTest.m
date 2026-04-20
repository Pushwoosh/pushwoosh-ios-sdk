
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWIdleDetector.h"
#import "PWScreenTrackingManager.h"
#import "PWAppLifecycleTrackingManager.h"
#import "PWUtils.h"
#import "PWInAppManager.h"
#import <PushwooshCore/PWManagerBridge.h>

@interface PWIdleDetector (Test)
- (void)registerActivity;
- (void)onIdleTimeout;
- (void)onResignActive;
- (void)onBecomeActive;
- (void)onDidEnterBackground;
- (void)onKeyboardWillShow;
- (void)onKeyboardDidHide;
@end

@interface PWScreenTrackingManager (Test)
@property (nonatomic, copy, readwrite) NSString *currentScreenName;
@end

@interface PWAppLifecycleTrackingManager (Test)
@property (nonatomic, assign, readwrite) NSTimeInterval foregroundMonotonicTimestamp;
@end

@interface PWIdleDetectorTest : XCTestCase

@property (nonatomic) PWIdleDetector *detector;
@property (nonatomic) id managerBridgeMock;
@property (nonatomic) id inAppManagerMock;
@property (nonatomic) id screenTrackingMock;
@property (nonatomic) id lifecycleMock;

@end

@implementation PWIdleDetectorTest

- (void)setUp {
    [super setUp];

    _detector = [[PWIdleDetector alloc] initWithIdleThreshold:5.0];
    _detector.defaultIdleTrackingAllowed = YES;

    _inAppManagerMock = OCMClassMock([PWInAppManager class]);
    _managerBridgeMock = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([_managerBridgeMock inAppManager]).andReturn(_inAppManagerMock);

    _screenTrackingMock = OCMPartialMock([PWScreenTrackingManager sharedManager]);
    [PWScreenTrackingManager sharedManager].currentScreenName = @"TestScreen";

    _lifecycleMock = OCMPartialMock([PWAppLifecycleTrackingManager sharedManager]);
    [PWAppLifecycleTrackingManager sharedManager].foregroundMonotonicTimestamp =
        [NSProcessInfo processInfo].systemUptime - 60;
}

- (void)tearDown {
    [_inAppManagerMock stopMocking];
    [_managerBridgeMock stopMocking];
    [_screenTrackingMock stopMocking];
    [_lifecycleMock stopMocking];
    [super tearDown];
}

#pragma mark - Tests

/// Verifies that idle event fires when the scheduled timeout block runs.
- (void)testIdleTimeoutFiresEvent {
    [_detector onIdleTimeout];

    OCMVerify([_inAppManagerMock postEvent:@"PW_UserIdle"
                           withAttributes:[OCMArg isNotNil]
                               completion:[OCMArg any]]);
}

/// Verifies that idle event does not fire twice within the same session.
- (void)testIdleDoesNotFireTwice {
    [_detector onIdleTimeout];

    id strictMock = OCMStrictClassMock([PWInAppManager class]);
    OCMStub([_managerBridgeMock inAppManager]).andReturn(strictMock);

    [_detector onIdleTimeout];

    [strictMock stopMocking];
}

/// Verifies that idle re-fires after true backgrounding (DidEnterBackground → become active).
- (void)testIdleReFiresAfterSessionReset {
    [_detector onIdleTimeout];

    [_detector onResignActive];
    [_detector onDidEnterBackground];
    [_detector onBecomeActive];
    [_detector onIdleTimeout];

    OCMVerify(times(2), [_inAppManagerMock postEvent:@"PW_UserIdle"
                                      withAttributes:[OCMArg isNotNil]
                                          completion:[OCMArg any]]);
}

/// Verifies that detector with threshold=0 (disabled via config) never schedules idle event.
- (void)testIdleDoesNotFireWhenThresholdIsZero {
    PWIdleDetector *disabledDetector = [[PWIdleDetector alloc] initWithIdleThreshold:0];
    disabledDetector.defaultIdleTrackingAllowed = YES;

    OCMReject([_inAppManagerMock postEvent:@"PW_UserIdle"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [disabledDetector registerActivity];

    XCTestExpectation *exp = [self expectationWithDescription:@"wait-no-fire"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        [exp fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

/// Verifies that detector with negative threshold (disabled via config) never fires.
- (void)testIdleDoesNotFireWhenThresholdIsNegative {
    PWIdleDetector *disabledDetector = [[PWIdleDetector alloc] initWithIdleThreshold:-1];
    disabledDetector.defaultIdleTrackingAllowed = YES;

    OCMReject([_inAppManagerMock postEvent:@"PW_UserIdle"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [disabledDetector registerActivity];

    XCTestExpectation *exp = [self expectationWithDescription:@"wait-no-fire"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        [exp fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

/// Verifies that brief resign/become-active (Control Center, alerts) does NOT reset one-shot flag.
- (void)testIdleDoesNotReFireOnBriefInterruption {
    [_detector onIdleTimeout];

    [_detector onResignActive];
    [_detector onBecomeActive];

    id strictMock = OCMStrictClassMock([PWInAppManager class]);
    OCMStub([_managerBridgeMock inAppManager]).andReturn(strictMock);

    [_detector onIdleTimeout];

    [strictMock stopMocking];
}

/// Verifies that onIdleTimeout is a no-op when paused (backgrounded).
- (void)testPauseOnResignActive {
    [_detector onResignActive];

    OCMReject([_inAppManagerMock postEvent:@"PW_UserIdle"
                           withAttributes:[OCMArg any]
                               completion:[OCMArg any]]);

    [_detector onIdleTimeout];
}

/// Verifies that onBecomeActive resumes the detector and allows idle firing.
- (void)testResumeOnBecomeActive {
    [_detector onResignActive];
    [_detector onBecomeActive];

    [_detector onIdleTimeout];

    OCMVerify([_inAppManagerMock postEvent:@"PW_UserIdle"
                           withAttributes:[OCMArg isNotNil]
                               completion:[OCMArg any]]);
}

/// Verifies that idle event does not fire when tracking is disabled.
- (void)testIdleDoesNotFireWhenDisabled {
    _detector.defaultIdleTrackingAllowed = NO;

    OCMReject([_inAppManagerMock postEvent:@"PW_UserIdle"
                           withAttributes:[OCMArg any]
                               completion:[OCMArg any]]);

    [_detector onIdleTimeout];
}

/// Verifies that idle event is suppressed while keyboard is visible.
- (void)testIdleSuppressedWhileKeyboardVisible {
    [_detector onKeyboardWillShow];

    OCMReject([_inAppManagerMock postEvent:@"PW_UserIdle"
                           withAttributes:[OCMArg any]
                               completion:[OCMArg any]]);

    [_detector onIdleTimeout];
}

/// Verifies that keyboard hide allows idle to fire again.
- (void)testIdleFiresAfterKeyboardHide {
    [_detector onKeyboardWillShow];
    [_detector onKeyboardDidHide];

    [_detector onIdleTimeout];

    OCMVerify([_inAppManagerMock postEvent:@"PW_UserIdle"
                           withAttributes:[OCMArg isNotNil]
                               completion:[OCMArg any]]);
}

/// Verifies that idle event attributes contain expected keys and `idle_seconds` equals the threshold.
- (void)testIdleEventAttributes {
    OCMExpect([_inAppManagerMock postEvent:@"PW_UserIdle"
                           withAttributes:[OCMArg checkWithBlock:^BOOL(NSDictionary *attrs) {
        return attrs[@"screen_name"] != nil &&
               [attrs[@"idle_seconds"] integerValue] == 5 &&
               attrs[@"session_duration"] != nil &&
               attrs[@"device_type"] != nil &&
               attrs[@"application_version"] != nil;
    }]
                               completion:[OCMArg any]]);

    [_detector onIdleTimeout];

    OCMVerifyAll(_inAppManagerMock);
}

@end
