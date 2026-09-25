#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWConfig.h"
#import "PWNotificationExtensionManager.h"
#import "PWNotificationServiceProcessor.h"
#import "PWNetworkModule.h"
#import "PWRequestManager.h"
#import "PWMessageDeliveryRequest.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface PWNotificationServiceProcessor (Test)
@property (nonatomic, strong) PWRequestManager *requestManager;
@end

@interface PWNotificationExtensionManagerTest : XCTestCase

@property (nonatomic) id mockPWNetworkModule;
@property (nonatomic) id stubbedRequestManager;
@property (nonatomic, strong) NSMutableArray *testMocks;

@end

@implementation PWNotificationExtensionManagerTest

- (void)setUp {
    _testMocks = [NSMutableArray new];
    _stubbedRequestManager = [self track:OCMClassMock([PWRequestManager class])];
    OCMStub([_stubbedRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });

    _mockPWNetworkModule = [self track:OCMPartialMock([PWNetworkModule module])];
    OCMStub([_mockPWNetworkModule inject:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWNotificationServiceProcessor *processor = nil;
        [invocation getArgument:&processor atIndex:2];
        processor.requestManager = self.stubbedRequestManager;
    });
}

- (void)tearDown {
    // A test interrupted by an exception never reaches its own stopMocking, and one mock that
    // refuses to stop must not leave the rest armed for whoever runs next.
    for (id mock in [self.testMocks reverseObjectEnumerator]) {
        @try {
            [mock stopMocking];
        } @catch (NSException *exception) {
            NSLog(@"stopMocking failed for %@: %@", mock, exception);
        }
    }
    [self.testMocks removeAllObjects];
}

/// Hands the mock back so the test reads as before, and remembers it for tearDown.
- (id)track:(id)mock {
    [self.testMocks addObject:mock];
    return mock;
}

/// Verifies an absolute pw_badge "0" resets badge_count to zero through the deprecated manager.
- (void)testExtensionWithFirstPush {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = [self track:OCMPartialMock([UNMutableNotificationContent alloc])];
    id mockRequest = [self track:OCMPartialMock(request)];
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    id mockPWConfig = [self track:OCMPartialMock([PWConfig config])];
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = [self track:OCMClassMock([NSUserDefaults class])];
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:@"badge_count"]).andReturn(0);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @"0"}, @"pw_msg": @"1"}));

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([mockNSUserDefaults setInteger:0 forKey:@"badge_count"]);
}

/// Verifies pw_badge "+2" over a saved count of 2 increments badge_count to 4.
- (void)testWithPlusSign {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = [self track:OCMPartialMock([UNMutableNotificationContent alloc])];
    id mockRequest = [self track:OCMPartialMock(request)];
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    id mockPWConfig = [self track:OCMPartialMock([PWConfig config])];
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = [self track:OCMClassMock([NSUserDefaults class])];
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:@"badge_count"]).andReturn(2);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @"+2"}, @"pw_msg": @"1"}));

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([mockNSUserDefaults setInteger:4 forKey:@"badge_count"]);
}

/// Verifies pw_badge "-2" over a saved count of 4 decrements badge_count to 2.
- (void)testWithMinusSign {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = [self track:OCMPartialMock([UNMutableNotificationContent alloc])];
    id mockRequest = [self track:OCMPartialMock(request)];
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    id mockPWConfig = [self track:OCMPartialMock([PWConfig config])];
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = [self track:OCMClassMock([NSUserDefaults class])];
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:@"badge_count"]).andReturn(4);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @"-2"}, @"pw_msg": @"1"}));

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([mockNSUserDefaults setInteger:2 forKey:@"badge_count"]);
}

/// Verifies pw_badge "-100" over a saved count of 4 clamps badge_count to 0.
- (void)testWithMinusSignIfResultLessZero {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = [self track:OCMPartialMock([UNMutableNotificationContent alloc])];
    id mockRequest = [self track:OCMPartialMock(request)];
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    id mockPWConfig = [self track:OCMPartialMock([PWConfig config])];
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = [self track:OCMClassMock([NSUserDefaults class])];
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:@"badge_count"]).andReturn(4);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @"-100"}, @"pw_msg": @"1"}));

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([mockNSUserDefaults setInteger:0 forKey:@"badge_count"]);
}

/// Verifies that an empty pw_badge value does not raise NSRangeException and resets the badge to zero.
- (void)testExtensionWithEmptyBadgeDoesNotCrash {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = [self track:OCMPartialMock([UNMutableNotificationContent alloc])];
    id mockRequest = [self track:OCMPartialMock(request)];
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    id mockPWConfig = [self track:OCMPartialMock([PWConfig config])];
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = [self track:OCMClassMock([NSUserDefaults class])];
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:@"badge_count"]).andReturn(0);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @""}, @"pw_msg": @"1"}));

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    XCTAssertNoThrow([[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:^(UNNotificationContent *content) {
        [exp fulfill];
    }]);

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([mockNSUserDefaults setInteger:0 forKey:@"badge_count"]);
}

/// Verifies that a non-string pw_badge value (e.g. a number) does not crash the extension.
- (void)testExtensionWithNonStringBadgeDoesNotCrash {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = [self track:OCMPartialMock([UNMutableNotificationContent alloc])];
    id mockRequest = [self track:OCMPartialMock(request)];
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    id mockPWConfig = [self track:OCMPartialMock([PWConfig config])];
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = [self track:OCMClassMock([NSUserDefaults class])];
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:@"badge_count"]).andReturn(0);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @5}, @"pw_msg": @"1"}));

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    XCTAssertNoThrow([[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:^(UNNotificationContent *content) {
        [exp fulfill];
    }]);

    [self waitForExpectationsWithTimeout:2 handler:nil];
}

/// Verifies that handleNotificationRequest:withAppGroups:contentHandler: calls the contentHandler for a non-Pushwoosh push instead of hanging.
- (void)testHandleWithAppGroupsCallsContentHandlerForForeignPush {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = [self track:OCMPartialMock([UNMutableNotificationContent alloc])];
    id mockRequest = [self track:OCMPartialMock(request)];
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"alert": @"hi"}}));

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    __block BOOL called = NO;
    void(^block)(UNNotificationContent *content) = ^(UNNotificationContent *content) {
        called = YES;
        [exp fulfill];
    };

    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request
                                                               withAppGroups:@"group.com.pushwoosh.demoapp_unit_tests"
                                                              contentHandler:block];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertTrue(called);
}

/// Verifies a second handleNotificationRequest: on the shared manager still invokes the contentHandler (regression: a reused processor previously short-circuited on the consumed flag and never delivered the second push).
- (void)testSecondHandleStillDelivers {
    id mockPWConfig = [self track:OCMPartialMock([PWConfig config])];
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = [self track:OCMClassMock([NSUserDefaults class])];
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:OCMOCK_ANY]).andReturn(0);

    for (NSInteger i = 0; i < 2; i++) {
        UNNotificationRequest *request = [UNNotificationRequest alloc];
        id mockContent = [self track:OCMPartialMock([UNMutableNotificationContent alloc])];
        id mockRequest = [self track:OCMPartialMock(request)];
        OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockContent);
        OCMStub([mockContent mutableCopy]).andReturn(mockContent);
        OCMStub([(UNMutableNotificationContent *)mockContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @"0"}, @"pw_msg": @"1"}));

        XCTestExpectation *exp = [self expectationWithDescription:[NSString stringWithFormat:@"delivered %ld", (long)i]];
        [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:^(UNNotificationContent *content) {
            [exp fulfill];
        }];

        [self waitForExpectationsWithTimeout:2 handler:nil];
    }
}

/// Verifies that handleNotificationRequest:withAppGroups: sends the message delivery event (regression: this path previously handled only badges and skipped delivery + attachment).
- (void)testHandleWithAppGroupsSendsDeliveryEvent {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = [self track:OCMPartialMock([UNMutableNotificationContent alloc])];
    id mockRequest = [self track:OCMPartialMock(request)];
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}));

    id mockNSUserDefaults = [self track:OCMClassMock([NSUserDefaults class])];
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:OCMOCK_ANY]).andReturn(0);

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request
                                                               withAppGroups:@"group.com.pushwoosh.demoapp_unit_tests"
                                                              contentHandler:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([self.stubbedRequestManager sendRequest:[OCMArg isKindOfClass:[PWMessageDeliveryRequest class]] completion:OCMOCK_ANY]);
}

@end

#pragma clang diagnostic pop
