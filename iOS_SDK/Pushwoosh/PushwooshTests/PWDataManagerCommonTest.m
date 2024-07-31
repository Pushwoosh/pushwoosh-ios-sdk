//
//  PWDataManager.m
//  PushwooshTests
//
//  Created by André Kis on 24.07.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWDataManager.common.h"
#import "PWConfig.h"
#import "PWAppLifecycleTrackingManager.h"
#import "PWNetworkModule.h"

@interface PWDataManagerCommonTest : XCTestCase

@end

@interface PWDataManagerCommon (TESTS)

- (void)defaultEvents;

@end

@implementation PWDataManagerCommonTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testInitializationWithoutSendingEvents {
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    id mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    OCMExpect([mockNetworkModule inject:[OCMArg any]]);
    OCMStub([mockConfig config]).andReturn(mockConfig);
    OCMStub([mockConfig isCollectingLifecycleEventsAllowed]).andReturn(YES);
    id mockManager = OCMPartialMock([[PWDataManagerCommon alloc] init]);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"defaultEvents should be called if info.plist flag equal true"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    
    [self waitForExpectations:@[expectation] timeout:2];
    
    OCMVerify([mockManager defaultEvents]);
    
    [mockNetworkModule stopMocking];
    [mockConfig stopMocking];
    [mockManager stopMocking];
}

- (void)testInitializationWithoutSendingEventsByDefault {
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    OCMExpect([mockNetworkModule inject:[OCMArg any]]);
    id mockManager = OCMPartialMock([[PWDataManagerCommon alloc] init]);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"defaultEvents should be called by default"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    
    [self waitForExpectations:@[expectation] timeout:2];
    
    OCMVerify([mockManager defaultEvents]);
    
    [mockNetworkModule stopMocking];
    [mockManager stopMocking];
}

@end
