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

@interface PWSdkStateProvider (GateTest)
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *taskQueue;
- (void)resetForTesting;
@end

@interface PushwooshConfigGateTest : XCTestCase
@property (nonatomic) id mockBridge;
@end

@implementation PushwooshConfigGateTest

- (void)setUp {
    [super setUp];
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    _mockBridge = OCMPartialMock([PWManagerBridge shared]);
}

- (void)tearDown {
    [_mockBridge stopMocking];
    _mockBridge = nil;
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

    [self waitForExpectationsWithTimeout:2 handler:nil];
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

    [self waitForExpectationsWithTimeout:2 handler:nil];
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
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqualObjects(calls, (@[@"setTags", @"registerSmsNumber"]));
}

@end
