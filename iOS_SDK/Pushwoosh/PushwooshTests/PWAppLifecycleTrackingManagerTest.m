
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWAppLifecycleTrackingManager.h"
#import "PWUtils.h"
#import "PWInAppManager.h"
#import <PushwooshCore/PWManagerBridge.h>

@interface PWAppLifecycleTrackingManager (Test)
@property (nonatomic, strong, readwrite) NSDate *foregroundTimestamp;
@property (nonatomic) BOOL defaultAppClosedAllowed;
@property (nonatomic) BOOL appInForeground;
- (void)onApplicationClosed;
- (void)onApplicationOpen;
- (void)sendDefaultEvent:(NSString *)event;
@end

@interface PWAppLifecycleTrackingManagerTest : XCTestCase

@property (nonatomic) id managerBridgeMock;
@property (nonatomic) id inAppManagerMock;

@end

@implementation PWAppLifecycleTrackingManagerTest

- (void)setUp {
    [super setUp];

    _inAppManagerMock = OCMClassMock([PWInAppManager class]);
    _managerBridgeMock = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([_managerBridgeMock inAppManager]).andReturn(_inAppManagerMock);
}

- (void)tearDown {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = NO;

    [_inAppManagerMock stopMocking];
    [_managerBridgeMock stopMocking];
    [super tearDown];
}

#pragma mark - Tests

/// Verifies that PW_ApplicationMinimized fires immediately when app is closed.
- (void)testMinimizedFiresOnAppClose {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = YES;
    manager.appInForeground = YES;

    [manager onApplicationClosed];

    OCMVerify([_inAppManagerMock postEvent:@"PW_ApplicationMinimized"
                           withAttributes:[OCMArg isNotNil]
                               completion:[OCMArg any]]);
}

/// Verifies that foregroundTimestamp is set after onApplicationOpen.
- (void)testForegroundTimestampSetOnOpen {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.foregroundTimestamp = nil;

    [manager onApplicationOpen];

    XCTAssertNotNil(manager.foregroundTimestamp);
}

/// Verifies that event does not fire when defaultAppClosedAllowed is NO.
- (void)testNoEventWhenAppClosedNotAllowed {
    PWAppLifecycleTrackingManager *manager = [PWAppLifecycleTrackingManager sharedManager];
    manager.defaultAppClosedAllowed = NO;
    manager.appInForeground = YES;

    OCMReject([_inAppManagerMock postEvent:@"PW_ApplicationMinimized"
                           withAttributes:[OCMArg any]
                               completion:[OCMArg any]]);

    [manager onApplicationClosed];
}

@end
