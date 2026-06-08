//
//  PWNotificationExtensionManagerTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 28.03.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWConfig.h"
#import "PWNotificationExtensionManager.h"
#import "PWNetworkModule.h"

@interface PWNotificationExtensionManagerTest : XCTestCase

@property (nonatomic) id mockPWNetworkModule;

@end

@implementation PWNotificationExtensionManagerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _mockPWNetworkModule = OCMPartialMock([PWNetworkModule module]);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [self.mockPWNetworkModule stopMocking];
}

- (void)testExtensionWithFirstPush {
    OCMStub([_mockPWNetworkModule inject:OCMOCK_ANY]).andDo(nil);
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = OCMPartialMock([UNMutableNotificationContent alloc]);
    id mockRequest = OCMPartialMock(request);
    id mockUNNotificationContent = OCMClassMock([UNNotificationContent class]);
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    void(^block)(UNNotificationContent *content);
    id mockPWConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:OCMOCK_ANY]).andReturn(0);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @"0"}, @"pw_msg": @"1"}));
    OCMExpect([mockNSUserDefaults setInteger:0 forKey:@"badge_count"]);
    
    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:block];
    
    OCMVerify([mockNSUserDefaults setInteger:0 forKey:OCMOCK_ANY]);
    [mockPWConfig stopMocking];
    [mockNSUserDefaults stopMocking];
    [mockUNMutableNotificationContent stopMocking];
    [mockRequest stopMocking];
    [mockUNNotificationContent stopMocking];
    mockUNMutableNotificationContent = nil;
}

- (void)testWithPlusSign {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = OCMPartialMock([UNMutableNotificationContent alloc]);
    id mockRequest = OCMPartialMock(request);
    id mockUNNotificationContent = OCMClassMock([UNNotificationContent class]);
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    void(^block)(UNNotificationContent *content);
    id mockPWConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:OCMOCK_ANY]).andReturn(0);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @"+2"}, @"pw_msg": @"1"}));
    OCMExpect([mockNSUserDefaults integerForKey:@"badge_count"]).andReturn(2);
    OCMExpect([mockNSUserDefaults setInteger:4 forKey:@"badge_count"]);

    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:block];

    OCMVerify([mockNSUserDefaults integerForKey:@"badge_count"]);
    OCMVerify([mockNSUserDefaults setInteger:2 forKey:@"badge_count"]);
    [mockPWConfig stopMocking];
    [mockNSUserDefaults stopMocking];
    [mockUNMutableNotificationContent stopMocking];
    [mockRequest stopMocking];
    [mockUNNotificationContent stopMocking];
    mockUNMutableNotificationContent = nil;
}

- (void)testWithMinusSign {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = OCMPartialMock([UNMutableNotificationContent alloc]);
    id mockRequest = OCMPartialMock(request);
    id mockUNNotificationContent = OCMClassMock([UNNotificationContent class]);
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    void(^block)(UNNotificationContent *content);
    id mockPWConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:OCMOCK_ANY]).andReturn(4);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @"-2"}, @"pw_msg": @"1"}));
    OCMExpect([mockNSUserDefaults setInteger:2 forKey:@"badge_count"]);

    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:block];

    OCMVerify([mockNSUserDefaults integerForKey:@"badge_count"]);
    OCMVerify([mockNSUserDefaults setInteger:2 forKey:@"badge_count"]);
    [mockPWConfig stopMocking];
    [mockNSUserDefaults stopMocking];
    [mockUNMutableNotificationContent stopMocking];
    [mockRequest stopMocking];
    [mockUNNotificationContent stopMocking];
    mockUNMutableNotificationContent = nil;
}

- (void)testWithMinusSignIfResultLessZero {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = OCMPartialMock([UNMutableNotificationContent alloc]);
    id mockRequest = OCMPartialMock(request);
    id mockUNNotificationContent = OCMClassMock([UNNotificationContent class]);
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    void(^block)(UNNotificationContent *content);
    id mockPWConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:OCMOCK_ANY]).andReturn(4);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @"-100"}, @"pw_msg": @"1"}));
    OCMExpect([mockNSUserDefaults setInteger:0 forKey:@"badge_count"]);

    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:block];

    OCMVerify([mockNSUserDefaults integerForKey:@"badge_count"]);
    OCMVerify([mockNSUserDefaults setInteger:0 forKey:@"badge_count"]);
    [mockPWConfig stopMocking];
    [mockNSUserDefaults stopMocking];
    [mockUNMutableNotificationContent stopMocking];
    [mockRequest stopMocking];
    [mockUNNotificationContent stopMocking];
    mockUNMutableNotificationContent = nil;
}

/// Verifies that an empty pw_badge value does not raise NSRangeException and resets the badge to zero.
- (void)testExtensionWithEmptyBadgeDoesNotCrash {
    OCMStub([_mockPWNetworkModule inject:OCMOCK_ANY]).andDo(nil);
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = OCMPartialMock([UNMutableNotificationContent alloc]);
    id mockRequest = OCMPartialMock(request);
    id mockUNNotificationContent = OCMClassMock([UNNotificationContent class]);
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    void(^block)(UNNotificationContent *content);
    id mockPWConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:OCMOCK_ANY]).andReturn(0);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @""}, @"pw_msg": @"1"}));

    XCTAssertNoThrow([[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:block]);

    OCMVerify([mockNSUserDefaults setInteger:0 forKey:@"badge_count"]);
    [mockPWConfig stopMocking];
    [mockNSUserDefaults stopMocking];
    [mockUNMutableNotificationContent stopMocking];
    [mockRequest stopMocking];
    [mockUNNotificationContent stopMocking];
    mockUNMutableNotificationContent = nil;
}

/// Verifies that a non-string pw_badge value (e.g. a number) does not crash the extension.
- (void)testExtensionWithNonStringBadgeDoesNotCrash {
    OCMStub([_mockPWNetworkModule inject:OCMOCK_ANY]).andDo(nil);
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = OCMPartialMock([UNMutableNotificationContent alloc]);
    id mockRequest = OCMPartialMock(request);
    id mockUNNotificationContent = OCMClassMock([UNNotificationContent class]);
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    void(^block)(UNNotificationContent *content);
    id mockPWConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");
    id mockNSUserDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:OCMOCK_ANY]).andReturn(0);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"pw_badge": @5}, @"pw_msg": @"1"}));

    XCTAssertNoThrow([[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request contentHandler:block]);

    [mockPWConfig stopMocking];
    [mockNSUserDefaults stopMocking];
    [mockUNMutableNotificationContent stopMocking];
    [mockRequest stopMocking];
    [mockUNNotificationContent stopMocking];
    mockUNMutableNotificationContent = nil;
}

/// Verifies that handleNotificationRequest:withAppGroups:contentHandler: calls the contentHandler for a non-Pushwoosh push instead of hanging.
- (void)testHandleWithAppGroupsCallsContentHandlerForForeignPush {
    OCMStub([_mockPWNetworkModule inject:OCMOCK_ANY]).andDo(nil);
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = OCMPartialMock([UNMutableNotificationContent alloc]);
    id mockRequest = OCMPartialMock(request);
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{@"alert": @"hi"}}));

    __block BOOL called = NO;
    void(^block)(UNNotificationContent *content) = ^(UNNotificationContent *content) {
        called = YES;
    };

    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request
                                                               withAppGroups:@"group.com.pushwoosh.demoapp_unit_tests"
                                                              contentHandler:block];

    XCTAssertTrue(called);
    [mockUNMutableNotificationContent stopMocking];
    [mockRequest stopMocking];
    mockUNMutableNotificationContent = nil;
}

/// Verifies that handleNotificationRequest:withAppGroups:contentHandler: calls the contentHandler on the early return when PWConfig already holds an app groups name.
- (void)testHandleWithAppGroupsCallsContentHandlerWhenConfigGroupSet {
    OCMStub([_mockPWNetworkModule inject:OCMOCK_ANY]).andDo(nil);
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockUNMutableNotificationContent = OCMPartialMock([UNMutableNotificationContent alloc]);
    id mockRequest = OCMPartialMock(request);
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockUNMutableNotificationContent);
    OCMStub([mockUNMutableNotificationContent mutableCopy]).andReturn(mockUNMutableNotificationContent);
    OCMStub([(UNMutableNotificationContent *)mockUNMutableNotificationContent userInfo]).andReturn((@{@"aps": @{}, @"pw_msg": @"1"}));
    id mockPWConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfig appGroupsName]).andReturn(@"group.com.pushwoosh.demoapp_unit_tests");

    __block BOOL called = NO;
    void(^block)(UNNotificationContent *content) = ^(UNNotificationContent *content) {
        called = YES;
    };

    [[PWNotificationExtensionManager sharedManager] handleNotificationRequest:request
                                                               withAppGroups:@"group.com.example_app"
                                                              contentHandler:block];

    XCTAssertTrue(called);
    [mockPWConfig stopMocking];
    [mockUNMutableNotificationContent stopMocking];
    [mockRequest stopMocking];
    mockUNMutableNotificationContent = nil;
}

@end
