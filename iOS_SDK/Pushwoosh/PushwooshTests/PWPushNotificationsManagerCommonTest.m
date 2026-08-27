//
//  PWPushNotificationsManagerCommonTest.m
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
#import "PWRichPushManager.h"
#import <PushwooshCore/PWManagerBridge.h>

#import <UserNotifications/UserNotifications.h>
#import <OCMock/OCMock.h>

static BOOL isBackground;

@interface PWPushNotificationsManagerCommon(test) <PushNotificationDelegate>

@property (nonatomic, strong) PWRequestManager *requestManager;

- (void)sendDevTokenToServer:(NSString *)deviceID;
- (NSURL *)deepLinkUrlForUserInfo:(NSDictionary *)userInfo;

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

/// Verifies that non-string page ids from a payload are filtered out before they reach the rich push
/// manager. Checked on the h/r branches on purpose: they are dispatched synchronously, while the
/// deep-link branch runs off a main-queue timer that cannot be awaited reliably here — this suite
/// blocks the main queue for two seconds per getStatusesMask call.
- (void)testProcessActionUserInfoIgnoresNonStringPageIds {
    id richPushManagerMock = OCMClassMock([PWRichPushManager class]);
    id bridgeMock = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([bridgeMock richPushManager]).andReturn(richPushManagerMock);

    OCMReject([richPushManagerMock showPushPage:OCMOCK_ANY]);
    OCMReject([richPushManagerMock showCustomPushPageWithURLString:OCMOCK_ANY]);

    [_pushManager processActionUserInfo:@{ @"h" : @123, @"r" : @456 }];

    [bridgeMock stopMocking];
    [richPushManagerMock stopMocking];
}

/// Verifies that a string page id still reaches the rich push manager after the type check.
- (void)testProcessActionUserInfoOpensStringPageId {
    id richPushManagerMock = OCMClassMock([PWRichPushManager class]);
    id bridgeMock = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([bridgeMock richPushManager]).andReturn(richPushManagerMock);

    OCMExpect([richPushManagerMock showPushPage:@"page-1"]);

    [_pushManager processActionUserInfo:@{ @"h" : @"page-1" }];

    OCMVerifyAll(richPushManagerMock);

    [bridgeMock stopMocking];
    [richPushManagerMock stopMocking];
}

/// Verifies that a string deep link still resolves to a URL, and that a non-string one resolves to
/// nothing. Asserted on the resolver rather than on the opening: the opening waits on a main-queue
/// timer, and the previous version of this check was dropped for being flaky — which left the "l"
/// type filtering with no positive test at all, while a dead deep link is worse for a client than a
/// crash (a crash shows up in Crashlytics the same day, "opens the wrong place" arrives as a ticket
/// a month later).
- (void)testDeepLinkResolverFiltersByType {
    id configMock = OCMClassMock([PWConfig class]);
    OCMStub([configMock config]).andReturn(configMock);
    OCMStub([(PWConfig *)configMock preHandleNotificationsWithUrl]).andReturn(YES);

    XCTAssertEqualObjects([_pushManager deepLinkUrlForUserInfo:@{ @"l" : @"https://example.com" }],
                          [NSURL URLWithString:@"https://example.com"]);
    XCTAssertNil([_pushManager deepLinkUrlForUserInfo:@{ @"l" : @123 }]);
    XCTAssertNil([_pushManager deepLinkUrlForUserInfo:@{ @"l" : @"" }]);
    XCTAssertNil([_pushManager deepLinkUrlForUserInfo:@{}]);

    [configMock stopMocking];
}

/// Verifies that a silent push opens its deep link only when the app opted in. The rule moved into the
/// resolver together with the rest of the decision, so it now lives in a testable place and is covered
/// here rather than staying an untested branch.
- (void)testDeepLinkResolverHonoursSilentPushOptIn {
    id configMock = OCMClassMock([PWConfig class]);
    OCMStub([configMock config]).andReturn(configMock);
    OCMStub([(PWConfig *)configMock preHandleNotificationsWithUrl]).andReturn(YES);

    NSDictionary *silentPush = @{ @"l" : @"https://example.com",
                                  @"aps" : @{ @"content-available" : @1 } };

    OCMStub([(PWConfig *)configMock acceptedDeepLinkForSilentPush]).andReturn(NO);
    XCTAssertNil([_pushManager deepLinkUrlForUserInfo:silentPush],
                 @"a silent push must not open a deep link unless the app accepted it");

    [configMock stopMocking];

    id acceptingConfig = OCMClassMock([PWConfig class]);
    OCMStub([acceptingConfig config]).andReturn(acceptingConfig);
    OCMStub([(PWConfig *)acceptingConfig preHandleNotificationsWithUrl]).andReturn(YES);
    OCMStub([(PWConfig *)acceptingConfig acceptedDeepLinkForSilentPush]).andReturn(YES);

    XCTAssertEqualObjects([_pushManager deepLinkUrlForUserInfo:silentPush],
                          [NSURL URLWithString:@"https://example.com"]);

    [acceptingConfig stopMocking];
}

@end
