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
#if TARGET_OS_IOS
#import "PWNotificationManagerCompatUserNotifications.h"
#endif
#import "PWDataManager.h"
#import "PWSessionRetrySender.h"
#import "PWRegisterDeviceRequest.h"
#import <PushwooshCore/PWManagerBridge.h>
#import <UserNotifications/UserNotifications.h>

#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface PWNotificationManagerTest : XCTestCase

@property PushNotificationManager *pushManager;

@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;
@property (nonatomic) PWPushNotificationsManagerCommon *pushNotificationsManagerCommon;
@property (nonatomic, strong) NSMutableArray *mocks;
@property (nonatomic) NSInteger originalLastStatusMask;

@end

@interface PWPushNotificationsManagerCommon (TEST)

- (void)sendDevTokenToServer:(NSString *)deviceID triggerCallbacks:(BOOL)triggerCallbacks;
- (void)sendTokenToDelegate:(NSString *)deviceID triggerCallbacks:(BOOL)triggerCallbacks;
- (void)sendDevTokenToServer:(NSString *)deviceID triggerCallbacks:(BOOL)triggerCallbacks notificationStatus:(NSDictionary *)notificationStatus;
- (void)notificationStatusSyncCompleted:(NSNotification *)notification;

@property (nonatomic, copy) NSString *lastPushPermissionStatus;

@end

#if TARGET_OS_IOS
@interface PWNotificationManagerCompatUserNotifications (TEST)

+ (NSString *)pushPermissionStatusForAuthorizationStatus:(UNAuthorizationStatus)authorizationStatus;

@end
#endif

@implementation PWNotificationManagerTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    id notificationManagerMock = mock([PWNotificationManagerCompat class]);
    self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
    [PWPlatformModule module].notificationManagerCompat = notificationManagerMock;

    self.pushNotificationsManagerCommon = [[PWPushNotificationsManagerCommon alloc] init];
    self.mocks = [NSMutableArray array];
    self.originalLastStatusMask = [PWPreferences preferences].lastStatusMask;
}

- (id)tracked:(id)mock {
    [self.mocks addObject:mock];
    return mock;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    for (id mock in self.mocks) {
        [mock stopMocking];
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"PWLastPushPermissionStatus"];
    [PWPreferences preferences].lastStatusMask = self.originalLastStatusMask;
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

#if TARGET_OS_IOS
/// Verifies that every UNAuthorizationStatus maps to the Push Permission Status tag vocabulary.
- (void)testPushPermissionStatusMapping {
    Class compat = [PWNotificationManagerCompatUserNotifications class];
    XCTAssertEqualObjects([compat pushPermissionStatusForAuthorizationStatus:UNAuthorizationStatusAuthorized], @"granted_explicit");
    XCTAssertEqualObjects([compat pushPermissionStatusForAuthorizationStatus:UNAuthorizationStatusProvisional], @"provisional");
    XCTAssertEqualObjects([compat pushPermissionStatusForAuthorizationStatus:UNAuthorizationStatusEphemeral], @"ephemeral");
    XCTAssertEqualObjects([compat pushPermissionStatusForAuthorizationStatus:UNAuthorizationStatusDenied], @"denied");
    XCTAssertEqualObjects([compat pushPermissionStatusForAuthorizationStatus:UNAuthorizationStatusNotDetermined], @"not_determined");
    XCTAssertNil([compat pushPermissionStatusForAuthorizationStatus:(UNAuthorizationStatus)99]);
}
#endif

- (void)setUpThrottledRegistration {
    PWPreferences *preferences = [PWPreferences preferences];
    preferences.lastRegTime = [NSDate date];
    preferences.lastStatusMask = 0;
    preferences.pushToken = @"fake_token";
}

- (id)sessionRetryMock {
    id mockSessionRetry = [self tracked:OCMClassMock([PWSessionRetrySender class])];
    [self.pushNotificationsManagerCommon setValue:mockSessionRetry forKey:@"sessionRetry"];
    return mockSessionRetry;
}

- (NSDictionary *)statusWithPermission:(NSString *)permission {
    return @{@"pushBadge": @"0", @"pushAlert": @"0", @"pushSound": @"0", @"push_permission_status": permission};
}

/// Verifies that registration stays throttled when token, mask and push permission status are all unchanged.
- (void)testRegistrationThrottledWhenPushPermissionStatusUnchanged {
    id mockPushManager = [self tracked:OCMPartialMock(self.pushNotificationsManagerCommon)];
    [self setUpThrottledRegistration];
    id mockSessionRetry = [self sessionRetryMock];
    self.pushNotificationsManagerCommon.lastPushPermissionStatus = @"provisional";
    OCMReject([mockSessionRetry sendWithRetry:[OCMArg any] completion:[OCMArg any]]);
    OCMExpect([mockPushManager sendTokenToDelegate:@"fake_token" triggerCallbacks:YES]);

    [self.pushNotificationsManagerCommon sendDevTokenToServer:@"fake_token" triggerCallbacks:YES notificationStatus:[self statusWithPermission:@"provisional"]];

    OCMVerifyAll(mockPushManager);
    OCMVerifyAll(mockSessionRetry);
}

/// Verifies that notDetermined -> provisional (mask stays 0) bypasses the throttle and re-sends registerDevice
/// built from the one settings snapshot, without a blocking getRemoteNotificationStatus read.
- (void)testRegistrationResentWhenPushPermissionStatusChanged {
    NSDictionary *status = [self statusWithPermission:@"provisional"];
    id mockBridge = [self tracked:OCMClassMock([PWManagerBridge class])];
    OCMReject(ClassMethod([mockBridge getRemoteNotificationStatus]));
    [self setUpThrottledRegistration];
    id mockSessionRetry = [self sessionRetryMock];
    self.pushNotificationsManagerCommon.lastPushPermissionStatus = @"not_determined";
    OCMExpect([mockSessionRetry sendWithRetry:[OCMArg checkWithBlock:^BOOL(PWRegisterDeviceRequest *request) {
        return [request.notificationStatus isEqualToDictionary:status];
    }] completion:[OCMArg any]]);

    [self.pushNotificationsManagerCommon sendDevTokenToServer:@"fake_token" triggerCallbacks:YES notificationStatus:status];

    OCMVerifyAll(mockSessionRetry);
    OCMVerifyAll(mockBridge);
    XCTAssertEqualObjects(self.pushNotificationsManagerCommon.lastPushPermissionStatus, @"provisional");
}

/// Verifies that the first launch after an SDK update (nothing remembered yet) sends the status once, with registerDevice.
- (void)testRegistrationSendsStatusWhenNothingRemembered {
    [self setUpThrottledRegistration];
    id mockSessionRetry = [self sessionRetryMock];
    OCMExpect([mockSessionRetry sendWithRetry:[OCMArg isKindOfClass:[PWRegisterDeviceRequest class]] completion:[OCMArg any]]);

    [self.pushNotificationsManagerCommon sendDevTokenToServer:@"fake_token" triggerCallbacks:NO notificationStatus:[self statusWithPermission:@"denied"]];

    OCMVerifyAll(mockSessionRetry);
    XCTAssertEqualObjects(self.pushNotificationsManagerCommon.lastPushPermissionStatus, @"denied");
}

/// Verifies that a failed registerDevice restores the status delivered before it instead of wiping it.
- (void)testRegistrationErrorRestoresPreviousPermissionStatus {
    [self setUpThrottledRegistration];
    id mockSessionRetry = [self sessionRetryMock];
    self.pushNotificationsManagerCommon.lastPushPermissionStatus = @"not_determined";
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
    OCMStub([mockSessionRetry sendWithRetry:[OCMArg any] completion:([OCMArg invokeBlockWithArgs:error, nil])]);

    [self.pushNotificationsManagerCommon sendDevTokenToServer:@"fake_token" triggerCallbacks:NO notificationStatus:[self statusWithPermission:@"granted_explicit"]];

    XCTAssertEqualObjects(self.pushNotificationsManagerCommon.lastPushPermissionStatus, @"not_determined");
}

/// Verifies that an older failed registerDevice does not roll back a status a newer request has already written.
- (void)testOlderRegistrationErrorKeepsNewerPermissionStatus {
    [self setUpThrottledRegistration];
    id mockSessionRetry = [self sessionRetryMock];
    NSMutableArray *completions = [NSMutableArray array];
    OCMStub([mockSessionRetry sendWithRetry:[OCMArg any] completion:[OCMArg checkWithBlock:^BOOL(id completion) {
        [completions addObject:[completion copy]];
        return YES;
    }]]);
    self.pushNotificationsManagerCommon.lastPushPermissionStatus = @"not_determined";

    [self.pushNotificationsManagerCommon sendDevTokenToServer:@"fake_token" triggerCallbacks:NO notificationStatus:[self statusWithPermission:@"granted_explicit"]];
    [self.pushNotificationsManagerCommon sendDevTokenToServer:@"fake_token" triggerCallbacks:NO notificationStatus:[self statusWithPermission:@"denied"]];
    XCTAssertEqual(completions.count, 2);
    void (^olderCompletion)(NSError *) = completions.firstObject;
    olderCompletion([NSError errorWithDomain:@"test" code:1 userInfo:nil]);

    XCTAssertEqualObjects(self.pushNotificationsManagerCommon.lastPushPermissionStatus, @"denied");
}

/// Verifies that a successful registerDevice keeps the status it carried.
- (void)testRegistrationSuccessKeepsSentPermissionStatus {
    [self setUpThrottledRegistration];
    id mockSessionRetry = [self sessionRetryMock];
    self.pushNotificationsManagerCommon.lastPushPermissionStatus = @"not_determined";
    OCMStub([mockSessionRetry sendWithRetry:[OCMArg any] completion:([OCMArg invokeBlockWithArgs:[NSNull null], nil])]);

    [self.pushNotificationsManagerCommon sendDevTokenToServer:@"fake_token" triggerCallbacks:NO notificationStatus:[self statusWithPermission:@"granted_explicit"]];

    XCTAssertEqualObjects(self.pushNotificationsManagerCommon.lastPushPermissionStatus, @"granted_explicit");
}

/// Verifies that finishing the authorization request re-runs registration for a known token and sends no applicationOpen.
- (void)testAuthorizationCompletionReRegistersInsteadOfAppOpen {
    id mockPushManager = [self tracked:OCMPartialMock(self.pushNotificationsManagerCommon)];
    [PWPreferences preferences].pushToken = @"fake_token";
    id mockDataManager = [self tracked:OCMClassMock([PWDataManager class])];
    PWDataManager *originalDataManager = [PWManagerBridge shared].dataManager;
    [PWManagerBridge shared].dataManager = mockDataManager;
    OCMReject([mockDataManager sendAppOpenWithCompletion:[OCMArg any]]);
    OCMExpect([mockPushManager sendDevTokenToServer:@"fake_token" triggerCallbacks:NO]);

    [self.pushNotificationsManagerCommon notificationStatusSyncCompleted:nil];

    OCMVerifyAll(mockPushManager);
    OCMVerifyAll(mockDataManager);
    [PWManagerBridge shared].dataManager = originalDataManager;
}

/// Verifies that without a push token the authorization completion sends nothing: the status rides the next request.
- (void)testAuthorizationCompletionWithoutTokenSendsNothing {
    id mockPushManager = [self tracked:OCMPartialMock(self.pushNotificationsManagerCommon)];
    [PWPreferences preferences].pushToken = nil;
    OCMReject([mockPushManager sendDevTokenToServer:[OCMArg any] triggerCallbacks:NO]);

    [self.pushNotificationsManagerCommon notificationStatusSyncCompleted:nil];

    OCMVerifyAll(mockPushManager);
}

@end
