//
//  PushwooshConfigGateTest.m
//  PushwooshTests
//
//  Created by André Kis
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PushwooshConfig.h"
#import "PWSdkStateProvider.h"
#import "PWPreferences.h"
#import "PWManagerBridge.h"
#import "PWInAppManager.h"
#import "PWInAppMessagesManager.h"

@interface PWSdkStateProvider (GateTest)
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *taskQueue;
- (void)resetForTesting;
@end

@interface PushwooshConfigGateTest : XCTestCase
@property (nonatomic) id mockBridge;
@property (nonatomic, strong) PWInAppManager *originalInAppManager;
@property (nonatomic, strong) PWInAppMessagesManager *originalInAppMessagesManager;
@end

@implementation PushwooshConfigGateTest

- (void)setUp {
    [super setUp];
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    _originalInAppManager = [PWManagerBridge shared].inAppManager;
    _originalInAppMessagesManager = [PWManagerBridge shared].inAppMessagesManager;
    _mockBridge = OCMPartialMock([PWManagerBridge shared]);
}

- (void)tearDown {
    [_mockBridge stopMocking];
    _mockBridge = nil;
    [PWManagerBridge shared].inAppManager = _originalInAppManager;
    [PWManagerBridge shared].inAppMessagesManager = _originalInAppMessagesManager;
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [super tearDown];
}

/// Verifies that setTags called before setReady lands in the task queue instead of hitting PWManagerBridge immediately.
- (void)testSetTags_beforeSetReady_queuesCall {
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 0);
    OCMReject([_mockBridge setTags:OCMOCK_ANY]);

    [PushwooshConfig setTags:@{@"plan": @"premium"}];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 1);
}

/// Verifies that a queued setTags call is executed on PWManagerBridge once setReady fires.
- (void)testSetTags_afterSetReady_flushesToBridge {
    XCTestExpectation *expectation = [self expectationWithDescription:@"bridge setTags called"];
    OCMStub([_mockBridge setTags:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
    });

    [PushwooshConfig setTags:@{@"plan": @"gold"}];
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 1);

    [[PWSdkStateProvider sharedInstance] setReady];

    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 0);
}

/// Verifies that registerSmsNumber is queued before setReady and forwarded afterwards, mirroring Android parity.
- (void)testRegisterSmsNumber_queuedThenFlushed {
    XCTestExpectation *expectation = [self expectationWithDescription:@"bridge registerSmsNumber called"];
    OCMStub([_mockBridge registerSmsNumber:@"+1234567890"]).andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
    });

    [PushwooshConfig registerSmsNumber:@"+1234567890"];
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 1);

    [[PWSdkStateProvider sharedInstance] setReady];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

/// Verifies FIFO order: two public calls made before setReady flush in the order they were enqueued.
- (void)testMultipleCalls_flushInFIFOOrder {
    NSMutableArray<NSString *> *calls = [NSMutableArray new];

    OCMStub([_mockBridge setTags:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        [calls addObject:@"setTags"];
    });
    OCMStub([_mockBridge registerSmsNumber:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        [calls addObject:@"registerSmsNumber"];
    });

    [PushwooshConfig setTags:@{@"a": @"1"}];
    [PushwooshConfig registerSmsNumber:@"+1"];
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 2);

    [[PWSdkStateProvider sharedInstance] setReady];

    XCTestExpectation *expectation = [self expectationWithDescription:@"both flushed"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTAssertEqualObjects(calls, (@[@"setTags", @"registerSmsNumber"]));
}

/// Verifies that postEvent made before setReady waits in the queue and reaches the inAppManager once the SDK is ready.
- (void)testPostEvent_queuedUntilReadyThenFlushed {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    [PWManagerBridge shared].inAppManager = mockInApp;
    XCTestExpectation *expectation = [self expectationWithDescription:@"inAppManager postEvent called"];
    OCMStub([mockInApp postEvent:@"early_event" withAttributes:[OCMArg any] completion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
    });

    [PushwooshConfig postEvent:@"early_event" withAttributes:nil completion:nil];
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 1);

    [[PWSdkStateProvider sharedInstance] setReady];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

/// Verifies that postEvent without a completion is also held by the readiness gate.
- (void)testPostEventWithoutCompletion_beforeSetReady_queuesCall {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    OCMReject([mockInApp postEvent:[OCMArg any] withAttributes:[OCMArg any]]);
    OCMReject([mockInApp postEvent:[OCMArg any] withAttributes:[OCMArg any] completion:[OCMArg any]]);
    [PWManagerBridge shared].inAppManager = mockInApp;

    [PushwooshConfig postEvent:@"early_event" withAttributes:@{@"k": @"v"}];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 1);
}

/// Verifies that resetUserId made before setReady waits in the queue and reaches the in-app messages manager once the SDK is ready.
- (void)testResetUserId_queuedUntilReadyThenFlushed {
    id mockMessages = OCMClassMock([PWInAppMessagesManager class]);
    [PWManagerBridge shared].inAppMessagesManager = mockMessages;
    XCTestExpectation *expectation = [self expectationWithDescription:@"inAppMessagesManager resetUserId called"];
    OCMStub([mockMessages resetUserIdWithCompletion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
    });

    [PushwooshConfig resetUserIdWithCompletion:nil];
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 1);

    [[PWSdkStateProvider sharedInstance] setReady];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

#if TARGET_OS_IOS
/// Verifies that reloadInApps made before setReady waits in the queue and reaches the inAppManager once the SDK is ready.
- (void)testReloadInApps_queuedUntilReadyThenFlushed {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    [PWManagerBridge shared].inAppManager = mockInApp;
    XCTestExpectation *expectation = [self expectationWithDescription:@"inAppManager reloadInApps called"];
    OCMStub([mockInApp reloadInAppsWithCompletion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
    });

    [PushwooshConfig reloadInAppsWithCompletion:nil];
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 1);

    [[PWSdkStateProvider sharedInstance] setReady];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

/// Verifies that addJavascriptInterface registers immediately, without waiting for the SDK to become ready.
- (void)testAddJavascriptInterface_beforeSetReady_notQueued {
    NSObject<PWJavaScriptInterface> *interface = (NSObject<PWJavaScriptInterface> *)[NSObject new];
    id mockInApp = OCMClassMock([PWInAppManager class]);
    OCMExpect([mockInApp addJavascriptInterface:interface withName:@"PushMart"]);
    [PWManagerBridge shared].inAppManager = mockInApp;

    [PushwooshConfig addJavascriptInterface:interface withName:@"PushMart"];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 0);
    OCMVerifyAll(mockInApp);
}
#endif

@end
