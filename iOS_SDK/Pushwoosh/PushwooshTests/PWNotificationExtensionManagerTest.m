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

@end
