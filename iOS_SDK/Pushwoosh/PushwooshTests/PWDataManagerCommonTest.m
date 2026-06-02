#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWDataManager.common.h"
#import "PWConfig.h"
#import "PWAppLifecycleTrackingManager.h"
#import "PWNetworkModule.h"

@interface PWDataManagerCommon (TESTS)

- (void)defaultEvents;

@end

@interface PWDataManagerCommonTest : XCTestCase

@end

@implementation PWDataManagerCommonTest

/// Verifies that init schedules defaultEvents on the operation queue when isCollectingLifecycleEventsAllowed is YES.
- (void)testInitCallsDefaultEventsWhenLifecycleEventsAllowed {
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    id mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([mockConfig config]).andReturn(mockConfig);
    OCMStub([mockConfig isCollectingLifecycleEventsAllowed]).andReturn(YES);

    PWDataManagerCommon *manager = [[PWDataManagerCommon alloc] init];
    id mockManager = OCMPartialMock(manager);

    XCTestExpectation *expectation = [self expectationWithDescription:@"defaultEvents called asynchronously"];
    OCMStub([mockManager defaultEvents]).andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
    });

    [self waitForExpectations:@[expectation] timeout:2];

    [mockNetworkModule stopMocking];
    [mockConfig stopMocking];
    [mockManager stopMocking];
}

/// Verifies that init does NOT call defaultEvents when isCollectingLifecycleEventsAllowed is NO.
- (void)testInitSkipsDefaultEventsWhenLifecycleEventsDisallowed {
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    id mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([mockConfig config]).andReturn(mockConfig);
    OCMStub([mockConfig isCollectingLifecycleEventsAllowed]).andReturn(NO);

    PWDataManagerCommon *manager = [[PWDataManagerCommon alloc] init];
    id mockManager = OCMPartialMock(manager);
    OCMReject([mockManager defaultEvents]);

    XCTestExpectation *settle = [self expectationWithDescription:@"operation queue drained"];
    [[NSOperationQueue currentQueue] addOperationWithBlock:^{
        [settle fulfill];
    }];
    [self waitForExpectations:@[settle] timeout:2];

    OCMVerifyAll(mockManager);

    [mockNetworkModule stopMocking];
    [mockConfig stopMocking];
    [mockManager stopMocking];
}

@end
