#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWScreenTrackingManager.h"
#import "PWManagerBridge.h"
#import "PWInAppManager.h"
#import "PWUtils.h"

@interface PWScreenTrackingManager (Test)

@property (nonatomic, copy, readwrite) NSString *currentScreenName;

@end

@interface PWScreenTrackingManagerTest : XCTestCase

@property (nonatomic, strong) PWScreenTrackingManager *manager;
@property (nonatomic, strong) id mockInApp;
@property (nonatomic, strong) PWInAppManager *originalInAppManager;
@property (nonatomic) BOOL originalDefaultAllowed;
@property (nonatomic) BOOL originalSuppress;
@property (nonatomic, copy) NSString *originalCurrentScreenName;

@end

@implementation PWScreenTrackingManagerTest

- (void)setUp {
    [super setUp];
    _manager = [PWScreenTrackingManager sharedManager];
    _originalInAppManager = [PWManagerBridge shared].inAppManager;
    _originalDefaultAllowed = _manager.defaultScreenOpenAllowed;
    _originalSuppress = _manager.suppressScreenOpened;
    _originalCurrentScreenName = [_manager.currentScreenName copy];
}

- (void)tearDown {
    [_mockInApp stopMocking];
    _mockInApp = nil;
    [PWManagerBridge shared].inAppManager = _originalInAppManager;
    _manager.defaultScreenOpenAllowed = _originalDefaultAllowed;
    _manager.suppressScreenOpened = _originalSuppress;
    _manager.currentScreenName = _originalCurrentScreenName;
    [super tearDown];
}

#pragma mark - Singleton

/// Verifies that sharedManager returns the same singleton instance across calls.
- (void)testSharedManagerIsSingleton {
    PWScreenTrackingManager *a = [PWScreenTrackingManager sharedManager];
    PWScreenTrackingManager *b = [PWScreenTrackingManager sharedManager];

    XCTAssertNotNil(a);
    XCTAssertEqual(a, b);
}

#pragma mark - defaultScreenOpenEvent

/// Verifies that the canonical event name is exactly "PW_ScreenOpen" (server-side analytics depends on this).
- (void)testDefaultScreenOpenEvent_isPWScreenOpen {
    XCTAssertEqualObjects(defaultScreenOpenEvent, @"PW_ScreenOpen");
}

#pragma mark - emitScreenOpenForCurrentScreen guards

/// Verifies that emitScreenOpenForCurrentScreen does NOT post an event when defaultScreenOpenAllowed is NO.
- (void)testEmit_defaultScreenOpenAllowedNo_doesNotPostEvent {
    id mockInApp = _mockInApp = OCMClassMock([PWInAppManager class]);
    OCMReject([mockInApp postEvent:[OCMArg any] withAttributes:[OCMArg any]]);
    [PWManagerBridge shared].inAppManager = mockInApp;
    _manager.defaultScreenOpenAllowed = NO;
    _manager.currentScreenName = @"SomeScreen";

    [_manager emitScreenOpenForCurrentScreen];

    OCMVerifyAll(mockInApp);
}

/// Verifies that emitScreenOpenForCurrentScreen does NOT post an event when suppressScreenOpened is YES.
- (void)testEmit_suppressed_doesNotPostEvent {
    id mockInApp = _mockInApp = OCMClassMock([PWInAppManager class]);
    OCMReject([mockInApp postEvent:[OCMArg any] withAttributes:[OCMArg any]]);
    [PWManagerBridge shared].inAppManager = mockInApp;
    _manager.defaultScreenOpenAllowed = YES;
    _manager.suppressScreenOpened = YES;
    _manager.currentScreenName = @"SomeScreen";

    [_manager emitScreenOpenForCurrentScreen];

    OCMVerifyAll(mockInApp);
}

/// Verifies that emitScreenOpenForCurrentScreen does NOT post an event when currentScreenName is nil.
- (void)testEmit_nilCurrentScreenName_doesNotPostEvent {
    id mockInApp = _mockInApp = OCMClassMock([PWInAppManager class]);
    OCMReject([mockInApp postEvent:[OCMArg any] withAttributes:[OCMArg any]]);
    [PWManagerBridge shared].inAppManager = mockInApp;
    _manager.defaultScreenOpenAllowed = YES;
    _manager.suppressScreenOpened = NO;
    _manager.currentScreenName = nil;

    [_manager emitScreenOpenForCurrentScreen];

    OCMVerifyAll(mockInApp);
}

/// Verifies that emitScreenOpenForCurrentScreen does NOT post an event when currentScreenName is an empty string.
- (void)testEmit_emptyCurrentScreenName_doesNotPostEvent {
    id mockInApp = _mockInApp = OCMClassMock([PWInAppManager class]);
    OCMReject([mockInApp postEvent:[OCMArg any] withAttributes:[OCMArg any]]);
    [PWManagerBridge shared].inAppManager = mockInApp;
    _manager.defaultScreenOpenAllowed = YES;
    _manager.suppressScreenOpened = NO;
    _manager.currentScreenName = @"";

    [_manager emitScreenOpenForCurrentScreen];

    OCMVerifyAll(mockInApp);
}

#pragma mark - emitScreenOpenForCurrentScreen happy path

/// Verifies that emitScreenOpenForCurrentScreen posts a PW_ScreenOpen event with screen_name, device_type=1, application_version when all guards pass.
- (void)testEmit_allGuardsPass_postsScreenOpenEventWithAttributes {
    id mockInApp = _mockInApp = OCMClassMock([PWInAppManager class]);
    OCMExpect([mockInApp postEvent:@"PW_ScreenOpen" withAttributes:[OCMArg checkWithBlock:^BOOL(NSDictionary *attrs) {
        return [attrs[@"screen_name"] isEqualToString:@"MyTestScreen"]
            && [attrs[@"device_type"] isEqual:@1]
            && attrs[@"application_version"] != nil;
    }]]);
    [PWManagerBridge shared].inAppManager = mockInApp;
    _manager.defaultScreenOpenAllowed = YES;
    _manager.suppressScreenOpened = NO;
    _manager.currentScreenName = @"MyTestScreen";

    [_manager emitScreenOpenForCurrentScreen];

    OCMVerifyAll(mockInApp);
}

/// Verifies that emitScreenOpenForCurrentScreen attaches the current PWUtils.appVersion as application_version.
- (void)testEmit_attributesIncludeAppVersionFromPWUtils {
    NSString *expectedVersion = [PWUtils appVersion];
    __block NSString *capturedVersion = nil;
    id mockInApp = _mockInApp = OCMClassMock([PWInAppManager class]);
    OCMStub([mockInApp postEvent:[OCMArg any] withAttributes:[OCMArg checkWithBlock:^BOOL(NSDictionary *attrs) {
        capturedVersion = attrs[@"application_version"];
        return YES;
    }]]);
    [PWManagerBridge shared].inAppManager = mockInApp;
    _manager.defaultScreenOpenAllowed = YES;
    _manager.suppressScreenOpened = NO;
    _manager.currentScreenName = @"Screen";

    [_manager emitScreenOpenForCurrentScreen];

    XCTAssertEqualObjects(capturedVersion, expectedVersion);
}

@end
