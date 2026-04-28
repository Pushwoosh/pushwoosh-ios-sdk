
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UIKit/UIKit.h>

#import "PWAppLifecycleTrackingManager.h"
#import "PWScreenTrackingManager.h"
#import "PWUtils.h"
#import "PWInAppManager.h"
#import <PushwooshCore/PWManagerBridge.h>

@interface PWAppLifecycleTrackingManager (Test)
@property (nonatomic, strong, readwrite) NSDate *foregroundTimestamp;
@property (nonatomic) BOOL defaultAppClosedAllowed;
@property (nonatomic) BOOL defaultAppOpenAllowed;
@property (nonatomic) BOOL appInForeground;
@property (nonatomic) BOOL applicationDidBecomeActive;
@property (nonatomic) BOOL serverCommunicationEnabled;
- (void)onApplicationClosed;
- (void)onApplicationOpen;
- (void)sendAppOpen;
- (void)sendDefaultEvent:(NSString *)event;
- (void)fireMinimizedEvent;
- (void)cancelMinimizedBlock;
- (void)onMinimizedBackgroundTaskExpired;
@end

@interface PWScreenTrackingManager (Test)
@property (nonatomic, assign) BOOL suppressScreenOpened;
@end

@interface PWAppLifecycleTrackingManagerTest : XCTestCase

@property (nonatomic) id managerBridgeMock;
@property (nonatomic) id inAppManagerMock;
@property (nonatomic) NSMutableArray *appClassMocks;
@property (nonatomic) id sharedApplicationStub;

@end

@implementation PWAppLifecycleTrackingManagerTest

- (void)setUp {
    [super setUp];

    _appClassMocks = [NSMutableArray array];
    _inAppManagerMock = OCMClassMock([PWInAppManager class]);
    _managerBridgeMock = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([_managerBridgeMock inAppManager]).andReturn(_inAppManagerMock);

    [self mockSharedApplication];
}

- (void)tearDown {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    [manager cancelMinimizedBlock];
    manager.defaultAppClosedAllowed = NO;
    [PWScreenTrackingManager sharedManager].suppressScreenOpened = NO;

    [_inAppManagerMock stopMocking];
    [_managerBridgeMock stopMocking];
    for (id m in _appClassMocks) {
        [m stopMocking];
    }
    [_appClassMocks removeAllObjects];
    _sharedApplicationStub = nil;
    [super tearDown];
}

#pragma mark - Tests

/// Verifies that PW_ApplicationMinimized is debounced and not fired synchronously on close.
- (void)testMinimizedNotFiredImmediatelyOnClose {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    OCMReject([_inAppManagerMock postEvent:@"PW_ApplicationMinimized"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [manager onApplicationClosed];
}

/// Verifies that PW_ApplicationMinimized fires after debounce timer completes.
- (void)testMinimizedFiresAfterDebounceCompletion {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    [manager onApplicationClosed];
    [manager fireMinimizedEvent];

    OCMVerify([_inAppManagerMock postEvent:@"PW_ApplicationMinimized"
                            withAttributes:[OCMArg isNotNil]
                                completion:[OCMArg any]]);
}

/// Verifies that rapid foreground within debounce window cancels pending minimized event.
- (void)testRapidBounceCancelsPendingMinimized {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    OCMReject([_inAppManagerMock postEvent:@"PW_ApplicationMinimized"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [manager onApplicationClosed];
    [manager onApplicationOpen];
    [manager fireMinimizedEvent];
}

/// Verifies that rapid bounce sets suppressScreenOpened flag synchronously.
- (void)testRapidBounceSetsSuppressScreenOpenedFlag {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    [manager onApplicationClosed];
    [manager onApplicationOpen];

    XCTAssertTrue([PWScreenTrackingManager sharedManager].suppressScreenOpened);
}

/// Verifies that suppressScreenOpened flag is cleared on the next main-queue tick.
- (void)testSuppressScreenOpenedFlagClearedAsync {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    [manager onApplicationClosed];
    [manager onApplicationOpen];

    XCTestExpectation *exp = [self expectationWithDescription:@"flag-cleared"];
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            XCTAssertFalse([PWScreenTrackingManager sharedManager].suppressScreenOpened);
            [exp fulfill];
        });
    });
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

/// Verifies that rapid bounce does not emit PW_ApplicationOpen.
- (void)testRapidBounceDoesNotEmitApplicationOpen {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    OCMReject([_inAppManagerMock postEvent:@"PW_ApplicationOpen"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [manager onApplicationClosed];
    [manager onApplicationOpen];
}

/// Verifies that normal close (debounce elapsed) followed by open still emits both events.
- (void)testNormalCloseAfterDebounceFiresMinimized {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    [manager onApplicationClosed];
    [manager fireMinimizedEvent];

    OCMVerify([_inAppManagerMock postEvent:@"PW_ApplicationMinimized"
                            withAttributes:[OCMArg isNotNil]
                                completion:[OCMArg any]]);
}

/// Verifies that no minimized event is scheduled when defaultAppClosedAllowed is NO.
- (void)testNoEventWhenAppClosedNotAllowed {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = NO;
    manager.appInForeground = YES;

    OCMReject([_inAppManagerMock postEvent:@"PW_ApplicationMinimized"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [manager onApplicationClosed];
    [manager fireMinimizedEvent];
}

/// Verifies that foregroundTimestamp is set after onApplicationOpen when not in rapid-bounce path.
- (void)testForegroundTimestampSetOnOpen {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.foregroundTimestamp = nil;

    [manager onApplicationOpen];

    XCTAssertNotNil(manager.foregroundTimestamp);
}

/// Verifies that suppressScreenOpened is NOT touched on legitimate foreground (debounce already elapsed).
- (void)testSuppressScreenOpenedNotSetOnLegitimateForeground {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    [manager onApplicationClosed];
    [manager fireMinimizedEvent];

    [PWScreenTrackingManager sharedManager].suppressScreenOpened = NO;

    [manager onApplicationOpen];

    XCTAssertFalse([PWScreenTrackingManager sharedManager].suppressScreenOpened);
}

/// Verifies that legitimate foreground after debounce window emits PW_ScreenOpen for the current screen.
- (void)testScreenOpenEmittedAfterLegitimateForegroundBeyondDebounce {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = NO;
    manager.applicationDidBecomeActive = YES;
    manager.serverCommunicationEnabled = YES;
    manager.defaultAppOpenAllowed = YES;

    id screenMock = OCMPartialMock([PWScreenTrackingManager sharedManager]);
    [PWScreenTrackingManager sharedManager].defaultScreenOpenAllowed = YES;
    [PWScreenTrackingManager sharedManager].suppressScreenOpened = NO;

    OCMExpect([screenMock emitScreenOpenForCurrentScreen]);

    [manager sendAppOpen];

    OCMVerifyAll(screenMock);
    [screenMock stopMocking];
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

/// Verifies that scheduling minimized debounce opens a UIApplication background task to survive iOS suspension.
- (void)testMinimizedDebounceOpensBackgroundTaskOnSchedule {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    id appMock = [self mockSharedApplication];
    OCMExpect([appMock beginBackgroundTaskWithName:@"PWApplicationMinimized"
                                 expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)55);

    [manager onApplicationClosed];

    OCMVerifyAll(appMock);
}

/// Verifies that firing the minimized debounce closes the background task.
- (void)testMinimizedDebounceEndsBackgroundTaskOnFire {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    id appMock = [self mockSharedApplication];
    OCMStub([appMock beginBackgroundTaskWithName:[OCMArg any]
                               expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)88);
    OCMExpect([appMock endBackgroundTask:(UIBackgroundTaskIdentifier)88]);

    [manager onApplicationClosed];
    [manager fireMinimizedEvent];

    OCMVerifyAll(appMock);
}

/// Verifies that rapid bounce (cancel) ends the minimized background task immediately.
- (void)testMinimizedDebounceEndsBackgroundTaskOnCancel {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    id appMock = [self mockSharedApplication];
    OCMStub([appMock beginBackgroundTaskWithName:[OCMArg any]
                               expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)200);
    OCMExpect([appMock endBackgroundTask:(UIBackgroundTaskIdentifier)200]);

    [manager onApplicationClosed];
    [manager onApplicationOpen];

    OCMVerifyAll(appMock);
}

/// Verifies that iOS-triggered minimized bg-task expiration drops the pending event without firing.
- (void)testMinimizedDebounceEndsBackgroundTaskOnExpirationWithoutFiring {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    id appMock = [self mockSharedApplication];
    OCMStub([appMock beginBackgroundTaskWithName:[OCMArg any]
                               expirationHandler:[OCMArg any]]).andReturn((UIBackgroundTaskIdentifier)321);
    OCMExpect([appMock endBackgroundTask:(UIBackgroundTaskIdentifier)321]);

    OCMReject([_inAppManagerMock postEvent:@"PW_ApplicationMinimized"
                            withAttributes:[OCMArg any]
                                completion:[OCMArg any]]);

    [manager onApplicationClosed];
    [manager onMinimizedBackgroundTaskExpired];
    [manager fireMinimizedEvent];

    OCMVerifyAll(appMock);
}

@end
