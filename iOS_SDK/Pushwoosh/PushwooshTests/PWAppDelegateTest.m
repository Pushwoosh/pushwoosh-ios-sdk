//
//  PWAppDelegateTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWAppDelegate.h"
#import "PushNotificationManager.h"
#import "PWTestUtils.h"

@interface PWAppDelegateTest : XCTestCase

@property (nonatomic) PWAppDelegate *appDelegate;

@end

@implementation PWAppDelegateTest

- (void)setUp {
    [PWTestUtils setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.appDelegate = [[PWAppDelegate alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [PWTestUtils tearDown];
    
    [super tearDown];
}

- (void)testDidFinishLaunchingWithOptions {
    UIApplication *application = [UIApplication sharedApplication];
    NSDictionary *launchOptions = @{};
    id mockPushNotificationManager = OCMPartialMock([PushNotificationManager pushManager]);
    OCMStub([mockPushNotificationManager notificationCenterDelegate]);
    OCMStub([mockPushNotificationManager sendAppOpen]);

    BOOL result = [self.appDelegate application:application didFinishLaunchingWithOptions:launchOptions];

    OCMVerify([mockPushNotificationManager notificationCenterDelegate]);
    OCMVerify([mockPushNotificationManager sendAppOpen]);
    XCTAssertTrue(result);
    [mockPushNotificationManager stopMocking];
}

- (void)testDidRegisterForRemoteNotificationsWithDeviceToken {
    UIApplication *application = [UIApplication sharedApplication];
    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"pushwoosh.com"]];
    id mockPushNotificationManager = OCMPartialMock([PushNotificationManager pushManager]);
    OCMStub([mockPushNotificationManager handlePushRegistration:data]);

    [self.appDelegate application:application didRegisterForRemoteNotificationsWithDeviceToken:data];

    OCMVerify([mockPushNotificationManager handlePushRegistration:data]);
    [mockPushNotificationManager stopMocking];
}

- (void)testDidFailToRegisterForRemoteNotificationsWithError {
    UIApplication *application = [UIApplication sharedApplication];
    NSError *error = [NSError errorWithDomain:@"pushwoosh.com" code:200 userInfo:@{}];
    id mockPushNotificationManager = OCMPartialMock([PushNotificationManager pushManager]);
    OCMStub([mockPushNotificationManager handlePushRegistrationFailure:error]);

    [self.appDelegate application:application didFailToRegisterForRemoteNotificationsWithError:error];

    OCMVerify([mockPushNotificationManager handlePushRegistrationFailure:error]);
    [mockPushNotificationManager stopMocking];
}

- (void)testDidReceiveRemoteNotification {
    UIApplication *application = [UIApplication sharedApplication];

    [self.appDelegate application:application didReceiveRemoteNotification:@{} fetchCompletionHandler:^(UIBackgroundFetchResult result) {
        XCTAssertEqual(result, UIBackgroundFetchResultNoData);
    }];
}

@end
