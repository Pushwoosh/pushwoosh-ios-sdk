//
//  PWNotificationManagerTest.m
//  PushNotificationManager
//
//  Created by etkachenko on 12/15/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWTestUtils.h"
#import "PushNotificationManager.h"
#import "PWPreferences.h"
#import "PWUtils.h"
#import "PWPlatformModule.h"
#import "PWNotificationCategoryBuilder.h"
#import "PWPushNotificationsManager.common.h"

#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface PWNotificationManagerTest : XCTestCase

@property PushNotificationManager *pushManager;

@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;
@property (nonatomic) PWPushNotificationsManagerCommon *pushNotificationsManagerCommon;

@end

@interface PWPushNotificationsManagerCommon (TEST)

- (void)sendDevTokenToServer:(NSString *)deviceID triggerCallbacks:(BOOL)triggerCallbacks;
- (void)sendTokenToDelegate:(NSString *)deviceID triggerCallbacks:(BOOL)triggerCallbacks;

@end

@implementation PWNotificationManagerTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    id notificationManagerMock = mock([PWNotificationManagerCompat class]);
    self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
    [PWPlatformModule module].notificationManagerCompat = notificationManagerMock;
    
    self.pushNotificationsManagerCommon = [[PWPushNotificationsManagerCommon alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
    [PWPlatformModule module].notificationManagerCompat = self.originalNotificationManager;
    [PWTestUtils tearDown];
}

/// Verifies that pushManager returns the same singleton instance across repeated calls.
- (void)testPushManagerReturnsSameSingleton {
    PushNotificationManager *first = [PushNotificationManager pushManager];
    PushNotificationManager *second = [PushNotificationManager pushManager];

    XCTAssertNotNil(first);
    XCTAssertEqual(first, second);
}

/// Verifies that initializeWithAppCode:appName: stores the provided appCode on the shared instance.
- (void)testInitializeWithAppCode {
    [PushNotificationManager initializeWithAppCode:@"testString1" appName:@"testString2"];

    XCTAssertEqualObjects([PushNotificationManager pushManager].appCode, @"testString1");
}

/// Verifies that PWUtils.getStatusesMask returns the mocked value when sendDevTokenToServer triggers a status check.
- (void)testLastStatusMaskIsEqualToPreviousValue {
    id mockPWSettings = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWSettings lastStatusMask]).andReturn(3);
    id mockPWUtils = OCMClassMock([PWUtils class]);
    OCMStub([mockPWUtils getStatusesMask]).andReturn(5);

    [self.pushNotificationsManagerCommon sendDevTokenToServer:@"fake_token" triggerCallbacks:YES];

    XCTAssertEqual([PWUtils getStatusesMask], 5);

    [mockPWSettings stopMocking];
    [mockPWUtils stopMocking];
}

/// Verifies that sendDevTokenToServer with triggerCallbacks:NO does NOT invoke sendTokenToDelegate when token/status are unchanged.
- (void)testSendTokenToDelegateNotCalled {
    NSDate *date = [NSDate date];
    id mockPushManager = OCMPartialMock(self.pushNotificationsManagerCommon);
    id mockPWUtils = OCMClassMock([PWUtils class]);
    OCMStub([mockPWUtils getStatusesMask]).andReturn(5);
    id mockPWPreferences = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWPreferences lastRegTime]).andReturn(date);
    OCMStub([mockPWPreferences lastStatusMask]).andReturn(3);
    OCMStub([mockPWPreferences pushToken]).andReturn(@"fake_token");
    OCMReject([mockPushManager sendTokenToDelegate:[OCMArg any] triggerCallbacks:[OCMArg any]]);

    [self.pushNotificationsManagerCommon sendDevTokenToServer:@"fake_token" triggerCallbacks:NO];

    OCMVerifyAll(mockPushManager);

    [mockPushManager stopMocking];
    [mockPWUtils stopMocking];
    [mockPWPreferences stopMocking];
}

@end
