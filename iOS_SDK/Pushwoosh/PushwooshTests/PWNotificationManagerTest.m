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

////+ (PushNotificationManager *)pushManager part

//tests method creates PushNotificationManager object
- (void)testPushManager { //
    
    //Precondition:
    
    
    //Steps:
    id pushManager = [PushNotificationManager pushManager];
    
    
    //Postcondition:
    
     XCTAssertTrue([pushManager isKindOfClass:[PushNotificationManager class]]);
}

////+ (void)initializeWithAppCode:(NSString *)appCode appName:(NSString *)appName part

//tests method creates object with correct appCode and appName
- (void)testInitializeWithAppCode {
    
    //Precondition:
    PushNotificationManager *pushManager = [PushNotificationManager pushManager];
    
    //Steps:
    [PushNotificationManager initializeWithAppCode:@"testString1" appName:@"testString2"];
    
    
    //Postcondition:
    XCTAssertEqualObjects(pushManager.appCode, @"testString1");
}

- (void)testLastStatusMaskIsEqualToPreviousValue {
    id mockPWPreferences = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWPreferences lastStatusMask]).andReturn(3);
    id mockPWUtils = OCMClassMock([PWUtils class]);
    OCMStub([mockPWUtils getStatusesMask]).andReturn(5);
    
    [self.pushNotificationsManagerCommon sendDevTokenToServer:@"fake_token" triggerCallbacks:YES];
    
    XCTAssertEqual([PWUtils getStatusesMask], 5);
}

- (void)testSendTokenToDelegateCalled {
    NSDate *date = [NSDate date];
    id mockPushManager = OCMPartialMock(self.pushNotificationsManagerCommon);
    id mockPWUtils = OCMClassMock([PWUtils class]);
    OCMStub([mockPWUtils getStatusesMask]).andReturn(3);
    id mockPWPreferences = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWPreferences lastRegTime]).andReturn(date);
    OCMStub([mockPWPreferences lastStatusMask]).andReturn(3);
    OCMStub([mockPWPreferences pushToken]).andReturn(@"fake_token");
    OCMExpect([mockPushManager sendTokenToDelegate:@"fake_token" triggerCallbacks:YES]);

    [self.pushNotificationsManagerCommon sendDevTokenToServer:@"fake_token" triggerCallbacks:YES];

    OCMVerifyAll(mockPushManager);
}

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
}

@end
