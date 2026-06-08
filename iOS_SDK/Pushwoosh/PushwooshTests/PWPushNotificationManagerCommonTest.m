//
//  PWPushNotificationManagerCommonTest.m
//  PushwooshTests
//
//  Created by Fectum on 20/09/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PWPushNotificationsManager.common.h"
#import "PushNotificationManager.h"
#import "PWDataManager.h"
#import "PushwooshFramework.h"
#import "PWBundleMock.h"
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import "PWVersionTracking.h"
#import "PWRequestManager.h"
#import "PWPreferences.h"

#import <UserNotifications/UserNotifications.h>
#import <OCMock/OCMock.h>

static BOOL isBackground;

@interface PWPushNotificationsManagerCommon(test) <PushNotificationDelegate>

@property (nonatomic, strong) PWRequestManager *requestManager;

- (void)sendDevTokenToServer:(NSString *)deviceID;

@end

@implementation PWPushNotificationsManagerCommon(test)

- (BOOL)isAppInBackground {
    return isBackground;
}

@end

@interface UNUserNotificationCenter (test)

+ (instancetype)currentNotificationCenter;

@end

@implementation UNUserNotificationCenter (test)

+ (instancetype)currentNotificationCenter {
    return nil;
}

@end

@interface PWVersionTracking (test)

@end

@implementation PWVersionTracking (test)

+ (NSString *)currentVersion {
    return @"";
}

+ (NSString *)currentBuild {
    return @"";
}

@end

@interface PWMockDataManager : PWDataManager

@property (nonatomic) NSUInteger pushStatCount;

- (void)sendStatsForPush:(NSDictionary *)pushDict;

@end

@implementation PWMockDataManager

- (void)sendStatsForPush:(NSDictionary *)pushDict {
    _pushStatCount++;
}

@end

@interface Pushwoosh ()

@property (nonatomic, strong) PWMockDataManager *dataManager;

@end

@interface PWPushNotificationsManagerCommonTest : XCTestCase

@property (nonatomic) PWPushNotificationsManagerCommon *pushManager;
@property (nonatomic) PWBundleMock *bundleMock;
@property (nonatomic, strong) id originalDataManager;

@end

@implementation PWPushNotificationsManagerCommonTest

- (void)setUp {
    [super setUp];
    _bundleMock = (id)[PWBundleMock new];
    _bundleMock.sendPushStatIfAlertsDisabled = YES;
    PWConfig *config = [[PWConfig alloc] initWithBundle:_bundleMock];
    _pushManager = [[PWPushNotificationsManagerCommon alloc] initWithConfig:config];
    _originalDataManager = (id)[Pushwoosh sharedInstance].dataManager;
    [Pushwoosh sharedInstance].dataManager = [PWMockDataManager new];
}

- (void)tearDown {
    [Pushwoosh sharedInstance].dataManager = _originalDataManager;
    [super tearDown];
}

- (void)testHandlePushReceivedShouldSentPushStatIfForegroundAlertsDisabled {
    isBackground = NO;
    [Pushwoosh sharedInstance].showPushnotificationAlert = NO;
    [_pushManager handlePushReceived:@{@"aps" : @{@"test" : @"test"}, @"pw_msg" : @"1"} autoAcceptAllowed:NO];
    XCTAssertEqual([Pushwoosh sharedInstance].dataManager.pushStatCount, 1);
}

- (void)testHandlePushReceivedShouldNotSentPushStatIfForegroundAlertsEnabled {
    isBackground = NO;
    [PushNotificationManager pushManager].showPushnotificationAlert = YES;
    [_pushManager handlePushReceived:@{@"aps" : @{@"test" : @"test", @"pw_msg" : @"1"}} autoAcceptAllowed:NO];
    XCTAssertEqual([Pushwoosh sharedInstance].dataManager.pushStatCount, 0);
}

- (void)testHandlePushReceivedShouldNotSentPushStatIfFromBackgroundYesForegroundAlertsEnabled {
    isBackground = YES;
    [PushNotificationManager pushManager].showPushnotificationAlert = YES;
    [_pushManager handlePushReceived:@{@"aps" : @{@"test" : @"test"}, @"pw_msg" : @"1"} autoAcceptAllowed:NO];
    XCTAssertEqual([Pushwoosh sharedInstance].dataManager.pushStatCount, 0);
}

- (void)testHandlePushReceivedShouldNotSentPushStatIfFromBackgroundYesAndForegroundAlertsDisabled {
    isBackground = YES;
    [PushNotificationManager pushManager].showPushnotificationAlert = NO;
    [_pushManager handlePushReceived:@{@"aps" : @{@"test" : @"test"}, @"pw_msg" : @"1"} autoAcceptAllowed:NO];
    XCTAssertEqual([Pushwoosh sharedInstance].dataManager.pushStatCount, 0);
}

- (void)testHandlePushReceived_ShouldSentPushStat_AlertDisabled_EnabledFlagInPlist_Foreground {
    isBackground = NO;
    [PushNotificationManager pushManager].showPushnotificationAlert = NO;
    [_pushManager handlePushReceived:@{@"aps" : @{@"test" : @"test"}, @"pw_msg" : @"1"} autoAcceptAllowed:YES];
    XCTAssertEqual([Pushwoosh sharedInstance].dataManager.pushStatCount, 1);
}

- (void)testHandlePushReceived_ShouldNotSentPushStat_AlertDisabled_DisabledFlagInPlist_Foreground {
    isBackground = NO;
    [PushNotificationManager pushManager].showPushnotificationAlert = NO;
    _bundleMock.sendPushStatIfAlertsDisabled = NO;
    
    PWConfig *config = [[PWConfig alloc] initWithBundle:_bundleMock];
    _pushManager = [[PWPushNotificationsManagerCommon alloc] initWithConfig:config];
    [Pushwoosh sharedInstance].dataManager = [PWMockDataManager new];
    
    [_pushManager handlePushReceived:@{@"aps" : @{@"test" : @"test"}} autoAcceptAllowed:NO];
    XCTAssertEqual([Pushwoosh sharedInstance].dataManager.pushStatCount, 0);
}

- (void)testHandlePushAccepted_ShouldSentPushStat {
    [_pushManager handlePushAccepted:@{@"aps" : @{@"test" : @"test"}} onStart:NO];
    XCTAssertEqual([Pushwoosh sharedInstance].dataManager.pushStatCount, 1);
}

/// Verifies that handlePushRegistrationString persists the dev token onto the shared Pushwoosh instance.
- (void)testSendDevTokenToServerWithoutErrorRequest {
    NSString *devToken = @"123198akjshdjkahds19ajhklsnnaskjdkas981023981hjasdasdasdaksjda";
    PWPushNotificationsManagerCommon *notificationManager = [[PWPushNotificationsManagerCommon alloc] init];
    id mockPWRequestManager = OCMPartialMock([notificationManager requestManager]);
    OCMStub([mockPWRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void(^handler)(NSError *error);
        [invocation getArgument:&handler atIndex:3];
        handler(nil);
    });

    [notificationManager handlePushRegistrationString:devToken];

    XCTAssertEqualObjects(devToken, [[Pushwoosh sharedInstance] getPushToken]);

    [mockPWRequestManager stopMocking];
}

/// Verifies that unregisterForPushNotificationsWithCompletion clears the persisted push token.
- (void)testUnregisterDeviceWithCompletion {
    PWPushNotificationsManagerCommon *notificationManager = [[PWPushNotificationsManagerCommon alloc] init];
    id mockPWRequestManager = OCMPartialMock([notificationManager requestManager]);
    OCMStub([mockPWRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void(^handler)(NSError *error);
        [invocation getArgument:&handler atIndex:3];
        handler(nil);
    });

    [notificationManager unregisterForPushNotificationsWithCompletion:^(NSError *error) {}];

    XCTAssertNil([[Pushwoosh sharedInstance] getPushToken]);

    [mockPWRequestManager stopMocking];
}

@end
