
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UIKit/UIKit.h>

#import "PWApplicationExitDetector.h"
#import "PWScreenTrackingManager.h"
#import "PWAppLifecycleTrackingManager.h"
#import "PWUtils.h"
#import "PWInAppManager.h"
#import <PushwooshCore/PWManagerBridge.h>

@interface PWApplicationExitDetector (Test)
- (void)onDidEnterBackground;
- (void)onDidBecomeActive;
- (void)onExitFired;
- (void)cancelExitBlock;
- (void)fireExitEvent;
- (void)beginBackgroundTask;
- (void)endBackgroundTask;
- (void)onBackgroundTaskExpired;
- (NSInteger)computeSessionDurationSeconds;
@end

@interface PWScreenTrackingManager (Test)
@property (nonatomic, copy, readwrite) NSString *currentScreenName;
@end

@interface PWAppLifecycleTrackingManager (Test)
@property (nonatomic, assign, readwrite) NSTimeInterval foregroundMonotonicTimestamp;
@end

@interface PWApplicationExitDetectorTest : XCTestCase

@property (nonatomic) PWApplicationExitDetector *detector;
@property (nonatomic) id managerBridgeMock;
@property (nonatomic) id inAppManagerMock;
@property (nonatomic) id screenTrackingMock;
@property (nonatomic) id lifecycleMock;
@property (nonatomic) NSMutableArray *appClassMocks;
@property (nonatomic) id sharedApplicationStub;

@end

@implementation PWApplicationExitDetectorTest

- (void)setUp {
    [super setUp];

    _appClassMocks = [NSMutableArray array];
    [self mockSharedApplication];

    _detector = [[PWApplicationExitDetector alloc] initWithExitTimeout:15.0];
    _detector.defaultApplicationExitTrackingAllowed = YES;

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
    for (id m in _appClassMocks) {
        [m stopMocking];
    }
    [_appClassMocks removeAllObjects];
    _sharedApplicationStub = nil;
    [super tearDown];
}

#pragma mark - Tests

/// Verifies that PW_ApplicationExit fires when the scheduled exit block runs.
- (void)testExitFiredEmitsApplicationExitEvent {
    [_detector onDidEnterBackground];
    [_detector onExitFired];

    OCMVerify([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg isNotNil]
                                completion:[OCMArg any]]);
}

/// Verifies that exit event payload carries the configured timeout in `exit_intent_seconds`.
- (void)testExitEventCarriesExitIntentTimeout {
    OCMExpect([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg checkWithBlock:^BOOL(NSDictionary *attrs) {
        return [attrs[@"exit_intent_seconds"] integerValue] == 15;
    }]
                                completion:[OCMArg any]]);

    [_detector onDidEnterBackground];
    [_detector onExitFired];

    OCMVerifyAll(_inAppManagerMock);
}

/// Verifies that exit event payload contains screen name snapshot from backgrounding moment.
- (void)testExitEventCarriesScreenName {
    [PWScreenTrackingManager sharedManager].currentScreenName = @"HomeScreen";

    OCMExpect([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg checkWithBlock:^BOOL(NSDictionary *attrs) {
        return [attrs[@"screen_name"] isEqualToString:@"HomeScreen"];
    }]
                                completion:[OCMArg any]]);

    [_detector onDidEnterBackground];
    [_detector onExitFired];

    OCMVerifyAll(_inAppManagerMock);
}

/// Verifies that exit event payload contains session_duration computed from monotonic timestamp.
- (void)testExitEventCarriesSessionDuration {
    OCMExpect([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg checkWithBlock:^BOOL(NSDictionary *attrs) {
        NSInteger sd = [attrs[@"session_duration"] integerValue];
        return sd >= 58 && sd <= 62;
    }]
                                completion:[OCMArg any]]);

    [_detector onDidEnterBackground];
    [_detector onExitFired];

    OCMVerifyAll(_inAppManagerMock);
}

/// Verifies that returning to foreground cancels the scheduled exit and prevents firing.
- (void)testForegroundCancelsScheduledExit {
    OCMReject([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [_detector onDidEnterBackground];
    [_detector onDidBecomeActive];
    [_detector onExitFired];
}

/// Verifies that screen name is captured at backgrounding (not at fire) — late changes are ignored.
- (void)testScreenNameSnapshotAtBackgroundingNotAtFire {
    [PWScreenTrackingManager sharedManager].currentScreenName = @"FirstScreen";
    [_detector onDidEnterBackground];

    [PWScreenTrackingManager sharedManager].currentScreenName = @"SecondScreen";

    OCMExpect([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg checkWithBlock:^BOOL(NSDictionary *attrs) {
        return [attrs[@"screen_name"] isEqualToString:@"FirstScreen"];
    }]
                                completion:[OCMArg any]]);

    [_detector onExitFired];

    OCMVerifyAll(_inAppManagerMock);
}

/// Verifies that no event fires when tracking is explicitly disabled.
- (void)testNoEventWhenTrackingDisabled {
    _detector.defaultApplicationExitTrackingAllowed = NO;

    OCMReject([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [_detector onDidEnterBackground];
    [_detector onExitFired];
}

/// Verifies that `screen_name` attribute is omitted when current screen name is nil at backgrounding.
- (void)testScreenNameAttributeOmittedWhenNil {
    [PWScreenTrackingManager sharedManager].currentScreenName = nil;

    OCMExpect([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg checkWithBlock:^BOOL(NSDictionary *attrs) {
        return attrs[@"screen_name"] == nil;
    }]
                                completion:[OCMArg any]]);

    [_detector onDidEnterBackground];
    [_detector onExitFired];

    OCMVerifyAll(_inAppManagerMock);
}

/// Verifies that detector with timeout=0 (disabled via config) never schedules exit event.
- (void)testNoEventWhenTimeoutIsZero {
    PWApplicationExitDetector *disabled = [[PWApplicationExitDetector alloc] initWithExitTimeout:0];
    disabled.defaultApplicationExitTrackingAllowed = YES;

    OCMReject([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [disabled onDidEnterBackground];
    [disabled onExitFired];
}

/// Verifies that exit event payload contains required fixed attributes.
- (void)testExitEventCarriesFixedAttributes {
    OCMExpect([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg checkWithBlock:^BOOL(NSDictionary *attrs) {
        return attrs[@"device_type"] != nil &&
               attrs[@"application_version"] != nil &&
               attrs[@"session_duration"] != nil &&
               attrs[@"exit_intent_seconds"] != nil;
    }]
                                completion:[OCMArg any]]);

    [_detector onDidEnterBackground];
    [_detector onExitFired];

    OCMVerifyAll(_inAppManagerMock);
}

/// Verifies that exit event payload carries the actual timeout used by the timer (10s).
- (void)testExitEventPayloadCarriesActualTimeout10 {
    PWApplicationExitDetector *detector = [[PWApplicationExitDetector alloc] initWithExitTimeout:10.0];
    detector.defaultApplicationExitTrackingAllowed = YES;

    OCMExpect([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg checkWithBlock:^BOOL(NSDictionary *attrs) {
        return [attrs[@"exit_intent_seconds"] integerValue] == 10;
    }]
                                completion:[OCMArg any]]);

    [detector onDidEnterBackground];
    [detector onExitFired];

    OCMVerifyAll(_inAppManagerMock);
}

/// Verifies that exit event payload carries the actual timeout used by the timer (20s).
- (void)testExitEventPayloadCarriesActualTimeout20 {
    PWApplicationExitDetector *detector = [[PWApplicationExitDetector alloc] initWithExitTimeout:20.0];
    detector.defaultApplicationExitTrackingAllowed = YES;

    OCMExpect([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg checkWithBlock:^BOOL(NSDictionary *attrs) {
        return [attrs[@"exit_intent_seconds"] integerValue] == 20;
    }]
                                completion:[OCMArg any]]);

    [detector onDidEnterBackground];
    [detector onExitFired];

    OCMVerifyAll(_inAppManagerMock);
}

/// Verifies that brief deactivation+reactivation cancels the scheduled exit and a fresh background re-schedules without double-fire.
- (void)testExitTimerCancelledOnBriefDeactivationAndReactivation {
    [_detector onDidEnterBackground];
    [_detector onDidBecomeActive];

    OCMExpect([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg isNotNil]
                                completion:[OCMArg any]]);

    [_detector onDidEnterBackground];
    [_detector onExitFired];

    OCMVerifyAll(_inAppManagerMock);
}

/// Verifies that calling onExitFired after a cancel does not emit the event (stale-block guard).
- (void)testStaleScheduledBlockDoesNotFireAfterCancel {
    OCMReject([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [_detector onDidEnterBackground];
    [_detector cancelExitBlock];
    [_detector onExitFired];
}

#pragma mark - Background task regression tests

- (id)mockSharedApplication {
    if (!_sharedApplicationStub) {
        id appClassMock = OCMClassMock([UIApplication class]);
        OCMStub([appClassMock sharedApplication]).andReturn(appClassMock);
        [_appClassMocks addObject:appClassMock];
        _sharedApplicationStub = appClassMock;
    }
    return _sharedApplicationStub;
}

/// Verifies that scheduling exit timer opens a UIApplication background task to survive iOS suspension.
- (void)testExitTimerOpensBackgroundTaskOnSchedule {
    id appMock = [self mockSharedApplication];
    OCMExpect([appMock beginBackgroundTaskWithName:@"PWApplicationExit"
                                 expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)42);

    [_detector onDidEnterBackground];

    OCMVerifyAll(appMock);
}

/// Verifies that firing the exit timer closes the background task.
- (void)testExitTimerEndsBackgroundTaskOnFire {
    id appMock = [self mockSharedApplication];
    OCMStub([appMock beginBackgroundTaskWithName:[OCMArg any]
                               expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)77);
    OCMExpect([appMock endBackgroundTask:(UIBackgroundTaskIdentifier)77]);

    [_detector onDidEnterBackground];
    [_detector onExitFired];

    OCMVerifyAll(appMock);
}

/// Verifies that returning to foreground closes the background task before iOS reclaims it.
- (void)testExitTimerEndsBackgroundTaskOnCancel {
    id appMock = [self mockSharedApplication];
    OCMStub([appMock beginBackgroundTaskWithName:[OCMArg any]
                               expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)123);
    OCMExpect([appMock endBackgroundTask:(UIBackgroundTaskIdentifier)123]);

    [_detector onDidEnterBackground];
    [_detector onDidBecomeActive];

    OCMVerifyAll(appMock);
}

/// Verifies that iOS-triggered background task expiration fires the event as a best-effort fallback before iOS reclaims the task.
- (void)testExitTimerFiresEventOnBackgroundTaskExpiration {
    id appMock = [self mockSharedApplication];
    OCMStub([appMock beginBackgroundTaskWithName:[OCMArg any]
                               expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)999);
    OCMExpect([appMock endBackgroundTask:(UIBackgroundTaskIdentifier)999]);

    OCMExpect([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg isNotNil]
                                completion:[OCMArg any]]);

    [_detector onDidEnterBackground];
    [_detector onBackgroundTaskExpired];
    [_detector onExitFired];

    OCMVerifyAll(appMock);
    OCMVerifyAll(_inAppManagerMock);
}

/// Verifies that timer firing first followed by iOS expirationHandler does not double-fire the event.
- (void)testExitTimerFiresOnceEvenIfTimerAndExpirationRaceCloselyTogether {
    id appMock = [self mockSharedApplication];
    OCMStub([appMock beginBackgroundTaskWithName:[OCMArg any]
                               expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)555);

    __block NSInteger postCount = 0;
    OCMStub([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                          withAttributes:[OCMArg any]
                              completion:[OCMArg any]]).andDo(^(NSInvocation *inv) {
        postCount++;
    });

    [_detector onDidEnterBackground];
    [_detector onExitFired];
    [_detector onBackgroundTaskExpired];

    XCTAssertEqual(postCount, 1, @"PW_ApplicationExit must be posted exactly once across timer fire and expiration race");
}

/// Verifies that iOS expirationHandler firing first, followed by a late timer block, does not double-fire the event.
- (void)testExitTimerFiresOnceWhenExpirationPrecedesTimerBlock {
    id appMock = [self mockSharedApplication];
    OCMStub([appMock beginBackgroundTaskWithName:[OCMArg any]
                               expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)777);

    __block NSInteger postCount = 0;
    OCMStub([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                          withAttributes:[OCMArg any]
                              completion:[OCMArg any]]).andDo(^(NSInvocation *inv) {
        postCount++;
    });

    [_detector onDidEnterBackground];
    [_detector onBackgroundTaskExpired];
    [_detector onExitFired];

    XCTAssertEqual(postCount, 1, @"PW_ApplicationExit must be posted exactly once when expiration precedes the late timer block");
}

/// Verifies that background task expiration does not fire the event when tracking is disabled, even if a previous schedule left state behind.
- (void)testExitTimerExpirationDoesNotFireWhenTrackingDisabled {
    id appMock = [self mockSharedApplication];
    OCMStub([appMock beginBackgroundTaskWithName:[OCMArg any]
                               expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)999);
    OCMExpect([appMock endBackgroundTask:(UIBackgroundTaskIdentifier)999]);

    OCMReject([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [_detector onDidEnterBackground];
    _detector.defaultApplicationExitTrackingAllowed = NO;

    [_detector onBackgroundTaskExpired];

    OCMVerifyAll(appMock);
    XCTAssertEqualObjects([_detector valueForKey:@"_scheduled"], @YES,
                          @"Disabled tracking must not mutate _scheduled — schedule remains until cancelled");
}

/// Verifies that expiration handler arriving after the timer has already fired does not re-fire the event.
- (void)testExitTimerExpirationIsNoOpWhenNotScheduled {
    id appMock = [self mockSharedApplication];
    OCMStub([appMock beginBackgroundTaskWithName:[OCMArg any]
                               expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)888);

    __block NSInteger postCount = 0;
    OCMStub([_inAppManagerMock postEvent:@"PW_ApplicationExit"
                          withAttributes:[OCMArg any]
                              completion:[OCMArg any]]).andDo(^(NSInvocation *inv) {
        postCount++;
    });

    [_detector onDidEnterBackground];
    [_detector onExitFired];

    [_detector onBackgroundTaskExpired];

    XCTAssertEqual(postCount, 1, @"PW_ApplicationExit must not fire again on late expiration when no exit is scheduled");
}

@end
