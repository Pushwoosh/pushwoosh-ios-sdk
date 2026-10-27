//
//  PWPushNotificationsManagerCommonTest.m
//  PushwooshTests
//
//  Created by Fectum on 20/09/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PWPushNotificationsManager.common.h"
#import "PWPushNotificationsManager.h"
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
#import "PWNetworkModule.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"
#import "PWSessionRetrySender.h"
#import "PWRegisterDeviceRequest.h"
#import "PWSetTagsRequest.h"
#import "PWUtils.h"
#import "PWFeatureFlagsManager.h"

#import <UserNotifications/UserNotifications.h>
#import <OCMock/OCMock.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static BOOL isBackground;

typedef void (^PWSessionReply)(NSData *data, NSURLResponse *response, NSError *error);

@interface PWPushNotificationsManagerCommon(test) <PushNotificationDelegate>

@property (nonatomic, strong) PWRequestManager *requestManager;
@property (nonatomic, strong) PWSessionRetrySender *sessionRetry;

- (void)sendDevTokenToServer:(NSString *)deviceID;
- (void)sendDevTokenToServer:(NSString *)deviceID triggerCallbacks:(BOOL)triggerCallbacks;
- (void)sendDevTokenToServer:(NSString *)deviceID triggerCallbacks:(BOOL)triggerCallbacks notificationStatus:(NSDictionary *)notificationStatus;
- (NSURL *)deepLinkUrlForUserInfo:(NSDictionary *)userInfo;
- (BOOL)presentRichContentForUserInfo:(NSDictionary *)userInfo;
- (void)openDeepLinkForUserInfo:(NSDictionary *)userInfo;

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

- (void)sendStatsForPush:(NSDictionary *)pushDict completion:(void (^)(void))completion;

@end

@implementation PWMockDataManager

- (void)sendStatsForPush:(NSDictionary *)pushDict completion:(void (^)(void))completion {
    _pushStatCount++;
    if (completion) {
        completion();
    }
}

@end

@interface Pushwoosh ()

@property (nonatomic, strong) PWMockDataManager *dataManager;

@end

@interface PWRequestManager (Test)

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSession *retrySession;

@end

@interface PWRegistrationDelegateRecorder : NSObject

@property (nonatomic, copy) NSString *registeredToken;
@property (nonatomic, strong) NSError *registrationError;

@end

@implementation PWRegistrationDelegateRecorder

- (void)onDidRegisterForRemoteNotificationsWithDeviceToken:(NSString *)token {
    self.registeredToken = token;
}

- (void)onDidFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    self.registrationError = error;
}

@end

@interface PWPushNotificationsManagerCommonTest : XCTestCase

@property (nonatomic) PWPushNotificationsManagerCommon *pushManager;
@property (nonatomic) PWBundleMock *bundleMock;
@property (nonatomic, strong) id originalDataManager;

@property (nonatomic, strong) id requestManagerMock;
@property (nonatomic, strong) id compatMock;
@property (nonatomic, strong) PWNotificationManagerCompat *savedCompat;
@property (nonatomic, copy) NSString *savedAppCode;
@property (nonatomic, copy) NSString *savedPushToken;
@property (nonatomic, copy) NSDate *savedLastRegTime;
@property (nonatomic) NSInteger savedLastStatusMask;
@property (nonatomic, copy) NSString *savedLanguage;
@property (nonatomic, copy) NSDictionary *savedActiveApplicationRecord;
@property (nonatomic, weak) id savedDelegate;
@property (nonatomic, strong) PWRegistrationDelegateRecorder *delegateRecorder;
@property (nonatomic, strong) NSSet<NSString *> *serverTokens;
@property (nonatomic) NSInteger serverStatusCode;
@property (nonatomic) BOOL serverHoldsReplies;
@property (nonatomic, strong) NSMutableArray<NSArray *> *heldReplies;
@property (nonatomic, strong) NSMapTable<PWRequest *, NSNumber *> *answerCodes;
@property (nonatomic, strong) NSMutableArray<PWRequest *> *registerAttempts;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *registerBodies;
@property (nonatomic, strong) NSURLSession *savedSession;
@property (nonatomic, strong) NSURLSession *savedRetrySession;
@property (nonatomic, strong) id sessionMock;
@property (nonatomic, strong) NSMutableArray *sessionTasks;

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
    if (_compatMock) {
        [self restoreRegistrationServer];
    }
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

/// Verifies that every device token handed to the manager is counted, whichever entry point delivered it.
- (void)testPushRegistrationCountGrowsWithEveryDelivery {
    PWPushNotificationsManagerCommon *notificationManager = [[PWPushNotificationsManagerCommon alloc] init];
    id mockPWRequestManager = OCMPartialMock([notificationManager requestManager]);
    OCMStub([mockPWRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]);

    [notificationManager handlePushRegistration:[@"token" dataUsingEncoding:NSUTF8StringEncoding]];
    [notificationManager handlePushRegistrationString:@"746f6b656e"];

    XCTAssertEqual(notificationManager.pushRegistrationCount, 2);

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

/// Verifies that an inbox card performs one destination: rich media wins and the `l` deep link
/// stays closed, so a tap cannot open two places at once.
- (void)testInboxActionPerformsRichMediaWithoutTheDeepLink {
    id managerMock = OCMPartialMock(_pushManager);
    OCMStub([managerMock presentRichContentForUserInfo:OCMOCK_ANY]).andReturn(YES);
    OCMReject([managerMock openDeepLinkForUserInfo:OCMOCK_ANY]);

    [_pushManager processInboxActionUserInfo:@{ @"rm" : @{ @"code" : @"RM-1" }, @"l" : @"https://example.com" }];

    OCMVerify([managerMock presentRichContentForUserInfo:OCMOCK_ANY]);
    [managerMock stopMocking];
}

/// Verifies that without rich content the inbox card falls through to its deep link.
- (void)testInboxActionOpensTheDeepLinkWhenThereIsNoRichContent {
    id managerMock = OCMPartialMock(_pushManager);
    OCMStub([managerMock presentRichContentForUserInfo:OCMOCK_ANY]).andReturn(NO);

    [_pushManager processInboxActionUserInfo:@{ @"l" : @"https://example.com" }];

    OCMVerify([managerMock openDeepLinkForUserInfo:OCMOCK_ANY]);
    [managerMock stopMocking];
}

/// Verifies that a plain push keeps doing both, unlike an inbox card: the split must not change
/// what notifications did before.
- (void)testPushActionStillPerformsRichMediaAndTheDeepLink {
    id managerMock = OCMPartialMock(_pushManager);
    OCMStub([managerMock presentRichContentForUserInfo:OCMOCK_ANY]).andReturn(YES);

    [_pushManager processActionUserInfo:@{ @"rm" : @{ @"code" : @"RM-1" }, @"l" : @"https://example.com" }];

    OCMVerify([managerMock presentRichContentForUserInfo:OCMOCK_ANY]);
    OCMVerify([managerMock openDeepLinkForUserInfo:OCMOCK_ANY]);
    [managerMock stopMocking];
}

#pragma mark - Registration in flight

/// Verifies that registering while the launch re-registration is in flight reports the server's failure, not the token.
- (void)testRegistrationDuringLaunchReregistrationReportsServerFailure {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-failure"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:503 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];
    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];
    [self waitForDelegate:^BOOL(PWRegistrationDelegateRecorder *delegate) {
        return delegate.registrationError != nil;
    }];

    XCTAssertNil(receivedToken);
    XCTAssertEqual(receivedError.code, 503);
    XCTAssertEqual(self.delegateRecorder.registrationError.code, 503);
    XCTAssertNil(self.delegateRecorder.registeredToken);
    XCTAssertEqual([self registrationsSent], 1);
    XCTAssertEqual(self.registerAttempts.count, 4);
}

/// Verifies that registering while the launch re-registration is in flight waits for the server and then gets the token.
- (void)testRegistrationDuringLaunchReregistrationWaitsForServerSuccess {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-success"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the server's answer");

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];
    [self waitForDelegate:^BOOL(PWRegistrationDelegateRecorder *delegate) {
        return delegate.registeredToken != nil;
    }];

    XCTAssertEqualObjects(receivedToken, token);
    XCTAssertNil(receivedError);
    XCTAssertEqualObjects(self.delegateRecorder.registeredToken, token);
    XCTAssertEqual([self registrationsSent], 1);
}

/// Verifies that a registration the server never confirmed is sent again on the next launch.
- (void)testUnconfirmedRegistrationIsSentAgainOnNextLaunch {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-relaunch"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];

    [[self newRegistrationManager] sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    [[self newRegistrationManager] sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);
}

/// Verifies that a new device token arriving during a registration in flight is registered with its own request.
- (void)testNewTokenDuringRegistrationInFlightIsRegistered {
    NSData *firstToken = [self tokenDataWithSeed:@"T1108-first"];
    NSData *secondToken = [self tokenDataWithSeed:@"T1108-second"];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ firstToken, secondToken ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:[self tokenForData:firstToken] triggerCallbacks:NO];
    [self drainMainQueue];
    [manager handlePushRegistration:secondToken];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqualObjects(((PWRegisterDeviceRequest *)self.registerAttempts.lastObject).token, [self tokenForData:secondToken]);
}

/// Verifies that registering after an unregister during a registration in flight sends a new request.
- (void)testRegistrationAfterUnregisterDuringFlightIsSent {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-unregister"];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:[self tokenForData:tokenData] triggerCallbacks:NO];
    [self drainMainQueue];
    [manager unregisterForPushNotificationsWithCompletion:nil];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);
}

/// Verifies that a language change during a registration in flight goes out with the next registration.
- (void)testLanguageChangeDuringRegistrationInFlightIsSent {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-language"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];
    NSString *language = [[PWPreferences preferences].language isEqualToString:@"fi"] ? @"sv" : @"fi";

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    [[PWPreferences preferences] setLanguage:language];
    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"language"], language);
}

/// Verifies that a superseded registration succeeding does not report the newer registration in flight as done.
- (void)testSupersededRegistrationSuccessDoesNotEndNewerRegistration {
    NSData *firstToken = [self tokenDataWithSeed:@"T1108-superseded-success-1"];
    NSData *secondToken = [self tokenDataWithSeed:@"T1108-superseded-success-2"];
    [self prepareRegistrationServerWithStatusCode:503 tokens:@[ firstToken, secondToken ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:[self tokenForData:firstToken] triggerCallbacks:NO];
    [self drainMainQueue];
    PWRequest *superseded = self.registerAttempts.lastObject;
    [manager handlePushRegistration:secondToken];
    [self drainMainQueue];
    [self releaseHeldRepliesOf:superseded statusCode:200];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:secondToken];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the newer registration");

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 1);
    XCTAssertNil(receivedToken);
    XCTAssertEqual(receivedError.code, 503);
    XCTAssertEqual([self registrationsSent], 2);
}

/// Verifies that a superseded registration failing does not make a repeat send a duplicate of the newer registration.
- (void)testSupersededRegistrationFailureDoesNotDuplicateNewerRegistration {
    NSData *firstToken = [self tokenDataWithSeed:@"T1108-superseded-failure-1"];
    NSData *secondToken = [self tokenDataWithSeed:@"T1108-superseded-failure-2"];
    NSString *token = [self tokenForData:secondToken];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ firstToken, secondToken ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:[self tokenForData:firstToken] triggerCallbacks:NO];
    [self drainMainQueue];
    PWRequest *superseded = self.registerAttempts.lastObject;
    [manager handlePushRegistration:secondToken];
    [self drainMainQueue];
    [self releaseHeldRepliesOf:superseded statusCode:503];
    [self waitUntil:^BOOL{
        return [self attemptsOf:superseded] == 4;
    }];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:secondToken];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the newer registration");

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 1);
    XCTAssertEqualObjects(receivedToken, token);
    XCTAssertNil(receivedError);
    XCTAssertEqual([self registrationsSent], 2);
}

/// Verifies that a registration sent before a language change does not hold the new language back once it succeeds.
- (void)testLanguageChangeDuringRegistrationInFlightIsSentAfterItSucceeds {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-language-success"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];
    NSString *language = [[PWPreferences preferences].language isEqualToString:@"fi"] ? @"sv" : @"fi";

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    [[PWPreferences preferences] setLanguage:language];
    [self releaseHeldReplies];
    [self drainMainQueue];
    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"language"], language);
}

/// Verifies that registering with tags during a registration in flight sends the tags and keeps them until its own answer.
- (void)testRegistrationWithTagsDuringRegistrationInFlightSendsTags {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-tags"];
    NSString *token = [self tokenForData:tokenData];
    NSDictionary *tags = @{ @"T1108": @"tags" };
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    PWRequest *withoutTags = self.registerAttempts.lastObject;

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    [[PWPreferences preferences] setCustomTags:tags];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"tags"], tags);

    [self releaseHeldRepliesOf:withoutTags statusCode:200];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the registration with tags");
    XCTAssertEqualObjects([PWPreferences preferences].customTags, tags);

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 1);
    XCTAssertEqualObjects(receivedToken, token);
    XCTAssertNil(receivedError);
    XCTAssertNil([PWPreferences preferences].customTags);
}

/// Verifies that registering with tags during a status change registration sends the tags instead of reporting the last registration.
- (void)testRegistrationWithTagsDuringStatusChangeRegistrationSendsTags {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-status-tags"];
    NSString *token = [self tokenForData:tokenData];
    NSDictionary *tags = @{ @"T1108": @"status-tags" };
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    [PWPreferences preferences].lastRegTime = [NSDate date];
    [PWPreferences preferences].lastStatusMask = [PWUtils statusesMaskFromNotificationStatus:@{}] + 1;
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    [[PWPreferences preferences] setCustomTags:tags];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the registration with tags");
    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"tags"], tags);

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];
}

/// Verifies that registering with tags while the app waits for a registration reports only the outcome of the registration with tags.
- (void)testRegistrationWithTagsWhileAppWaitsReportsOnlyItsOutcome {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-waiting-tags"];
    NSDictionary *tags = @{ @"T1108": @"waiting-tags" };
    [self prepareRegistrationServerWithStatusCode:503 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    PushwooshRegistrationHandler handler = ^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    };
    [manager registerForPushNotificationsWithCompletion:handler];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];
    PWRequest *waited = self.registerAttempts.lastObject;

    [[PWPreferences preferences] setCustomTags:tags];
    [manager registerForPushNotificationsWithCompletion:handler];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);

    [self releaseHeldRepliesOf:waited statusCode:200];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the registration with tags");

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];
    [self waitForDelegate:^BOOL(PWRegistrationDelegateRecorder *delegate) {
        return delegate.registrationError != nil;
    }];

    XCTAssertEqual(outcomes, 1);
    XCTAssertNil(receivedToken);
    XCTAssertEqual(receivedError.code, 503);
    XCTAssertNil(self.delegateRecorder.registeredToken);
}

/// Verifies that a status change registration sent while the app waits for a registration reports its outcome to the app once.
- (void)testStatusChangeRegistrationWhileAppWaitsReportsOnlyItsOutcome {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-waiting-status"];
    [self prepareRegistrationServerWithStatusCode:503 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];
    PWRequest *waited = self.registerAttempts.lastObject;

    [manager sendDevTokenToServer:[self tokenForData:tokenData] triggerCallbacks:NO notificationStatus:@{ @"pushAlert": @YES }];

    XCTAssertEqual([self registrationsSent], 2);

    [self releaseHeldRepliesOf:waited statusCode:200];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the status change registration");

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];
    [self waitForDelegate:^BOOL(PWRegistrationDelegateRecorder *delegate) {
        return delegate.registrationError != nil;
    }];

    XCTAssertEqual(outcomes, 1);
    XCTAssertNil(receivedToken);
    XCTAssertEqual(receivedError.code, 503);
    XCTAssertNil(self.delegateRecorder.registeredToken);
}

/// Verifies that a new device token arriving while the app waits for a registration reports only the new token's outcome.
- (void)testNewTokenWhileAppWaitsReportsOnlyItsOutcome {
    NSData *firstToken = [self tokenDataWithSeed:@"T1108-waiting-token-1"];
    NSData *secondToken = [self tokenDataWithSeed:@"T1108-waiting-token-2"];
    [self prepareRegistrationServerWithStatusCode:503 tokens:@[ firstToken, secondToken ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:firstToken];
    [self drainMainQueue];
    PWRequest *waited = self.registerAttempts.lastObject;

    [manager handlePushRegistration:secondToken];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);

    [self releaseHeldRepliesOf:waited statusCode:200];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the new token's registration");

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];
    [self waitForDelegate:^BOOL(PWRegistrationDelegateRecorder *delegate) {
        return delegate.registrationError != nil;
    }];

    XCTAssertEqual(outcomes, 1);
    XCTAssertNil(receivedToken);
    XCTAssertEqual(receivedError.code, 503);
    XCTAssertNil(self.delegateRecorder.registeredToken);
}

/// Verifies that a registration sent after the outcome was reported does not report to the app again.
- (void)testRegistrationAfterReportedOutcomeDoesNotReportAgain {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-reported"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];
    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];

    [manager sendDevTokenToServer:token triggerCallbacks:NO notificationStatus:@{ @"pushAlert": @YES }];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqual(outcomes, 1);
}

/// Verifies that tags delivered by a registration that a language change superseded are not sent again.
- (void)testTagsDeliveredBySupersededRegistrationAreNotSentAgain {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-delivered-tags"];
    NSString *token = [self tokenForData:tokenData];
    NSDictionary *tags = @{ @"T1108": @"delivered-tags" };
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];
    NSString *language = [[PWPreferences preferences].language isEqualToString:@"fi"] ? @"sv" : @"fi";

    [[PWPreferences preferences] setCustomTags:tags];
    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];

    XCTAssertEqualObjects(self.registerBodies.lastObject[@"tags"], tags);

    [[PWPreferences preferences] setLanguage:language];
    [self releaseHeldReplies];
    [self drainMainQueue];

    XCTAssertNil([PWPreferences preferences].customTags);

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"language"], language);
    XCTAssertNil(self.registerBodies.lastObject[@"tags"]);
}

/// Verifies that a registration the server confirmed is reported to the next call without a new request.
- (void)testConfirmedRegistrationIsReportedWithoutNewRequest {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-confirmed"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    [self releaseHeldReplies];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertEqualObjects(receivedToken, token);
    XCTAssertNil(receivedError);
    XCTAssertEqual([self registrationsSent], 1);
}

/// Verifies that a registration failing after a confirmed one makes the next call register again instead of reporting success.
- (void)testFailedRegistrationAfterConfirmedOneIsSentAgain {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-failed-after-confirmed"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    [PWPreferences preferences].lastRegTime = [NSDate date];
    [PWPreferences preferences].lastStatusMask = [PWUtils statusesMaskFromNotificationStatus:@{}] + 1;
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    PWRequest *failing = self.registerAttempts.lastObject;

    XCTAssertEqual([self registrationsSent], 1);

    [self releaseHeldRepliesOf:failing statusCode:503];
    [self waitUntil:^BOOL{
        return [self attemptsOf:failing] == 4;
    }];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for a new registration");
    XCTAssertEqual([self registrationsSent], 2);

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertEqual(outcomes, 1);
    XCTAssertEqualObjects(receivedToken, token);
}

/// Verifies that tags of a registration the server rejected go out with the next registration.
- (void)testTagsOfFailedRegistrationAreSentWithNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-failed-tags"];
    NSDictionary *tags = @{ @"T1108": @"failed-tags" };
    [self prepareRegistrationServerWithStatusCode:503 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    XCTestExpectation *failure = [self expectationWithDescription:@"registration failure"];
    [[PWPreferences preferences] setCustomTags:tags];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        [failure fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];
    [self releaseHeldReplies];
    [self waitForExpectations:@[ failure ] timeout:5];
    [self drainMainQueue];

    self.serverStatusCode = 200;
    XCTestExpectation *retried = [self expectationWithDescription:@"next registration outcome"];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        [retried fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self waitForExpectations:@[ retried ] timeout:5];

    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"tags"], tags);
}

/// Verifies that tags set while a registration without them is in flight are sent after that registration succeeds.
- (void)testTagsSetDuringRegistrationWithoutThemAreSentAfterItSucceeds {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-late-tags"];
    NSString *token = [self tokenForData:tokenData];
    NSDictionary *tags = @{ @"T1108": @"late-tags" };
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    PWRequest *withoutTags = self.registerAttempts.lastObject;

    [[PWPreferences preferences] setCustomTags:tags];
    [self releaseHeldRepliesOf:withoutTags statusCode:200];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the registration with tags");
    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"tags"], tags);

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertEqual(outcomes, 1);
    XCTAssertEqualObjects(receivedToken, token);
}

/// Verifies that registering with tags after a confirmed registration sends the tags once and then reports without a request.
- (void)testRegistrationWithTagsAfterConfirmedRegistrationSendsTags {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-confirmed-tags"];
    NSString *token = [self tokenForData:tokenData];
    NSDictionary *tags = @{ @"T1108": @"confirmed-tags" };
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    [self releaseHeldRepliesOf:self.registerAttempts.lastObject statusCode:200];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    [[PWPreferences preferences] setCustomTags:tags];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the registration with tags");
    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"tags"], tags);

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertEqual(outcomes, 1);
    XCTAssertEqualObjects(receivedToken, token);

    XCTestExpectation *confirmed = [self expectationWithDescription:@"confirmed registration outcome"];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        [confirmed fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self waitForExpectations:@[ confirmed ] timeout:5];

    XCTAssertEqual([self registrationsSent], 2);
}

/// Verifies that a date tag of a registration reaches the server as the same string setTags sends.
- (void)testRegistrationWithDateTagSendsItAsString {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-date-tag"];
    NSString *token = [self tokenForData:tokenData];
    NSDictionary *tags = @{ @"signup_date": [NSDate dateWithTimeIntervalSince1970:1760000000] };
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] statusForBody:^NSInteger(NSDictionary *body) {
        return 200;
    }];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];
    PWSetTagsRequest *setTags = [PWSetTagsRequest new];
    setTags.tags = tags;

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    [[PWPreferences preferences] setCustomTags:tags];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertNil(receivedError);
    XCTAssertEqualObjects(receivedToken, token);
    XCTAssertEqual(self.registerBodies.count, 1);
    XCTAssertTrue([self.registerBodies.lastObject[@"tags"][@"signup_date"] isKindOfClass:[NSString class]]);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"tags"], [setTags requestDictionary][@"tags"]);
}

/// Verifies that tags the server rejects for good do not hold back the next registration.
- (void)testTagsRejectedByServerDoNotBlockNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-rejected-tags"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] statusForBody:^NSInteger(NSDictionary *body) {
        return body[@"tags"] ? 400 : 200;
    }];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    XCTestExpectation *rejected = [self expectationWithDescription:@"rejected registration"];
    __block NSError *rejectionError = nil;
    [[PWPreferences preferences] setCustomTags:@{ @"T1108": @"rejected-tags" }];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        rejectionError = error;
        [rejected fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self waitForExpectations:@[ rejected ] timeout:5];

    XCTAssertNotNil(rejectionError);

    XCTestExpectation *outcome = [self expectationWithDescription:@"next registration outcome"];
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertNil(receivedError);
    XCTAssertEqualObjects(receivedToken, token);
    XCTAssertEqual(self.registerBodies.count, 2);
    XCTAssertNil(self.registerBodies.lastObject[@"tags"]);
}

/// Verifies that a registration answered after an app code change does not stand in for the registration of the new application.
- (void)testRegistrationAnsweredAfterAppCodeChangeDoesNotConfirmNewApplication {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-app-code"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    PWRequest *previousApplication = self.registerAttempts.lastObject;

    [PWPreferences preferences].appCode = @"T1108-00002";
    [self releaseHeldRepliesOf:previousApplication statusCode:200];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the registration of the new application");
    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"application"], @"T1108-00002");

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertEqual(outcomes, 1);
    XCTAssertEqualObjects(receivedToken, token);
}

/// Verifies that registering with an empty tag dictionary after a confirmed registration reports it without a request.
- (void)testRegistrationWithEmptyTagsAfterConfirmedRegistrationSendsNoRequest {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-empty-tags-confirmed"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    [self releaseHeldReplies];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    __block NSString *receivedToken = nil;
    [[PWPreferences preferences] setCustomTags:@{}];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        receivedToken = registeredToken;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertEqualObjects(receivedToken, token);
    XCTAssertEqual([self registrationsSent], 1);
}

/// Verifies that registering with an empty tag dictionary during a registration in flight waits for it.
- (void)testRegistrationWithEmptyTagsDuringRegistrationInFlightWaitsForIt {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-empty-tags-in-flight"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    [[PWPreferences preferences] setCustomTags:@{}];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the registration in flight");
    XCTAssertEqual([self registrationsSent], 1);

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertEqual(outcomes, 1);
    XCTAssertEqualObjects(receivedToken, token);
}

/// Verifies that registering after a return to the application whose registration was answered while away sends a new registration.
- (void)testRegistrationAfterReturnToApplicationAnsweredWhileAwayIsSent {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-answered-away"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    PWRequest *previousApplication = self.registerAttempts.lastObject;

    [PWPreferences preferences].appCode = @"T1108-00002";
    [self releaseHeldRepliesOf:previousApplication statusCode:200];
    [PWPreferences preferences].appCode = @"T1108-00001";
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"application"], @"T1108-00001");

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertEqual(outcomes, 1);
    XCTAssertEqualObjects(receivedToken, token);
}

/// Verifies that registering after the app code was cleared and set back while a registration was answered sends a new registration.
- (void)testRegistrationAfterAppCodeRestoredAnsweredWhileClearedIsSent {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-answered-cleared"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    PWRequest *previousApplication = self.registerAttempts.lastObject;

    [PWPreferences preferences].appCode = nil;
    [self releaseHeldRepliesOf:previousApplication statusCode:200];
    [PWPreferences preferences].appCode = @"T1108-00001";
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual([self registrationsSent], 2);

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertEqual(outcomes, 1);
    XCTAssertEqualObjects(receivedToken, token);
}

/// Verifies that registering after a return to the application while its registration is still in flight sends a new registration.
- (void)testRegistrationAfterReturnToApplicationDuringRegistrationInFlightIsSent {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-returned-in-flight"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];

    [PWPreferences preferences].appCode = @"T1108-00002";
    [PWPreferences preferences].appCode = @"T1108-00001";
    [self drainMainQueue];

    XCTestExpectation *outcome = [self expectationWithDescription:@"registration outcome"];
    outcome.assertForOverFulfill = NO;
    __block NSUInteger outcomes = 0;
    __block NSString *receivedToken = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        outcomes += 1;
        receivedToken = registeredToken;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self drainMainQueue];

    XCTAssertEqual(outcomes, 0, @"the outcome must wait for the registration sent after the return");
    XCTAssertEqual([self registrationsSent], 2);

    [self releaseHeldReplies];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertEqual(outcomes, 1);
    XCTAssertEqualObjects(receivedToken, token);
}

/// Verifies that a registration answered after an app code change does not mark the new application registered for feature flags.
- (void)testRegistrationAnsweredAfterAppCodeChangeDoesNotRegisterNewApplicationForFeatureFlags {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-feature-flags"];
    NSString *token = [self tokenForData:tokenData];
    [self prepareRegistrationServerWithStatusCode:200 tokens:@[ tokenData ]];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];
    id featureFlagsMock = OCMPartialMock([PWFeatureFlagsManager sharedManager]);
    __block NSUInteger flagRegistrations = 0;
    OCMStub([featureFlagsMock deviceRegistered]).andDo(^(NSInvocation *invocation) {
        flagRegistrations += 1;
    });

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    PWRequest *previousApplication = self.registerAttempts.lastObject;

    [PWPreferences preferences].appCode = @"T1108-00002";
    [self releaseHeldRepliesOf:previousApplication statusCode:200];
    [self drainMainQueue];

    XCTAssertEqual(flagRegistrations, 0);

    [manager sendDevTokenToServer:token triggerCallbacks:NO];
    [self drainMainQueue];
    [self releaseHeldReplies];
    [self drainMainQueue];

    XCTAssertEqual(flagRegistrations, 1);
    [featureFlagsMock stopMocking];
}

/// Verifies that tags of a registration that never reached the server go out with the next registration.
- (void)testTagsOfRegistrationWithoutServerAnswerAreSentWithNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-no-answer"];
    NSDictionary *tags = @{ @"T1108": @"no-answer" };
    __block NSUInteger attempts = 0;
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        attempts += 1;
        if (attempts == 1) {
            reply(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotFindHost userInfo:nil]);
        } else {
            [wSelf replyFromPushwoosh:reply url:url statusCode:200];
        }
    }];

    [self assertTagsOfFailedRegistrationAreSentWithNextRegistration:tags tokenData:tokenData];
}

/// Verifies that tags of a registration answered by a page that is not a Pushwoosh answer go out with the next registration.
- (void)testTagsOfRegistrationAnsweredByForeignPageAreSentWithNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-foreign-page"];
    NSDictionary *tags = @{ @"T1108": @"foreign-page" };
    __block NSUInteger attempts = 0;
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        attempts += 1;
        if (attempts == 1) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{ @"Content-Type": @"text/html" }];
            reply([@"<html><body>Sign in to the network</body></html>" dataUsingEncoding:NSUTF8StringEncoding], response, nil);
        } else {
            [wSelf replyFromPushwoosh:reply url:url statusCode:200];
        }
    }];

    [self assertTagsOfFailedRegistrationAreSentWithNextRegistration:tags tokenData:tokenData];
}

/// Verifies that tags of a registration whose retry never reached the server go out with the next registration.
- (void)testTagsOfRegistrationRetriedWithoutServerAnswerAreSentWithNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-retry-no-answer"];
    NSDictionary *tags = @{ @"T1108": @"retry-no-answer" };
    __block NSUInteger attempts = 0;
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        attempts += 1;
        if (attempts == 1) {
            [wSelf replyFromPushwoosh:reply url:url statusCode:503];
        } else if (attempts == 2) {
            reply(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotFindHost userInfo:nil]);
        } else {
            [wSelf replyFromPushwoosh:reply url:url statusCode:200];
        }
    }];

    [self assertTagsOfFailedRegistrationAreSentWithNextRegistration:tags tokenData:tokenData];
}

/// Verifies that tags of a registration a proxy refuses as too large do not hold back the next registration.
- (void)testTagsOfRegistrationRefusedByProxyAsTooLargeDoNotBlockNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-too-large"];
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        if (body[@"tags"]) {
            [wSelf replyWithPage:reply url:url statusCode:413];
        } else {
            [wSelf replyFromPushwoosh:reply url:url statusCode:200];
        }
    }];

    [self assertTagsOfRejectedRegistrationDoNotBlockNextRegistration:@{ @"T1108": @"too-large" } tokenData:tokenData];
}

/// Verifies that tags of a registration a web application firewall blocks do not hold back the next registration.
- (void)testTagsOfRegistrationBlockedByFirewallDoNotBlockNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-firewall"];
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        if (body[@"tags"]) {
            [wSelf replyWithPage:reply url:url statusCode:403];
        } else {
            [wSelf replyFromPushwoosh:reply url:url statusCode:200];
        }
    }];

    [self assertTagsOfRejectedRegistrationDoNotBlockNextRegistration:@{ @"T1108": @"firewall" } tokenData:tokenData];
}

/// Verifies that tags of a registration stopped by a captive portal login go out with the next registration.
- (void)testTagsOfRegistrationStoppedByCaptivePortalLoginAreSentWithNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-captive-login"];
    NSDictionary *tags = @{ @"T1108": @"captive-login" };
    __block NSUInteger attempts = 0;
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        attempts += 1;
        if (attempts == 1) {
            [wSelf replyWithPage:reply url:url statusCode:511];
        } else {
            [wSelf replyFromPushwoosh:reply url:url statusCode:200];
        }
    }];

    [self assertTagsOfFailedRegistrationAreSentWithNextRegistration:tags tokenData:tokenData];
}

/// Verifies that tags of a registration stopped by proxy authentication go out with the next registration.
- (void)testTagsOfRegistrationStoppedByProxyAuthenticationAreSentWithNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-proxy-auth"];
    NSDictionary *tags = @{ @"T1108": @"proxy-auth" };
    __block NSUInteger attempts = 0;
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        attempts += 1;
        if (attempts == 1) {
            [wSelf replyWithPage:reply url:url statusCode:407];
        } else {
            [wSelf replyFromPushwoosh:reply url:url statusCode:200];
        }
    }];

    [self assertTagsOfFailedRegistrationAreSentWithNextRegistration:tags tokenData:tokenData];
}

/// Verifies that tags of a registration answered by JSON without a Pushwoosh status code go out with the next registration.
- (void)testTagsOfRegistrationAnsweredByForeignJSONAreSentWithNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-foreign-json"];
    NSDictionary *tags = @{ @"T1108": @"foreign-json" };
    __block NSUInteger attempts = 0;
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        attempts += 1;
        if (attempts == 1) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{ @"Content-Type": @"application/json" }];
            reply([@"{\"error\":\"x\"}" dataUsingEncoding:NSUTF8StringEncoding], response, nil);
        } else {
            [wSelf replyFromPushwoosh:reply url:url statusCode:200];
        }
    }];

    [self assertTagsOfFailedRegistrationAreSentWithNextRegistration:tags tokenData:tokenData];
}

/// Verifies that tags of a registration a CDN fails with a 5xx page outside the retry policy go out with the next registration.
- (void)testTagsOfRegistrationFailedByCDNBeforePushwooshAreSentWithNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-cdn-origin-down"];
    NSDictionary *tags = @{ @"T1108": @"cdn-origin-down" };
    __block NSUInteger attempts = 0;
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        attempts += 1;
        if (attempts == 1) {
            [wSelf replyWithPage:reply url:url statusCode:522];
        } else {
            [wSelf replyFromPushwoosh:reply url:url statusCode:200];
        }
    }];

    [self assertTagsOfFailedRegistrationAreSentWithNextRegistration:tags tokenData:tokenData];
}

/// Verifies that tags Pushwoosh rejects with an error status code inside an HTTP 200 answer do not hold back the next registration.
- (void)testTagsRejectedByPushwooshWithinHTTPSuccessDoNotBlockNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-status-code-210"];
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        if (body[@"tags"]) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{ @"Content-Type": @"application/json" }];
            NSData *data = [NSJSONSerialization dataWithJSONObject:@{ @"status_code": @210, @"status_message": @"Rejected", @"response": @{} } options:0 error:nil];
            reply(data, response, nil);
        } else {
            [wSelf replyFromPushwoosh:reply url:url statusCode:200];
        }
    }];

    [self assertTagsOfRejectedRegistrationDoNotBlockNextRegistration:@{ @"T1108": @"status-code-210" } tokenData:tokenData];
}

/// Verifies that tags of a registration Pushwoosh answers with a retriable error on every attempt go out with the next registration.
- (void)testTagsOfRegistrationAnsweredByPushwooshWithRetriableErrorAreSentWithNextRegistration {
    NSData *tokenData = [self tokenDataWithSeed:@"T1108-pushwoosh-503"];
    NSDictionary *tags = @{ @"T1108": @"pushwoosh-503" };
    NSUInteger failedAttempts = 4;
    __block NSUInteger attempts = 0;
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:@[ tokenData ] replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        attempts += 1;
        [wSelf replyFromPushwoosh:reply url:url statusCode:attempts <= failedAttempts ? 503 : 200];
    }];

    [self assertTagsOfFailedRegistrationAreSentWithNextRegistration:tags tokenData:tokenData];
    XCTAssertEqual(attempts, failedAttempts + 1);
}

#pragma mark - Registration server

- (NSData *)tokenDataWithSeed:(NSString *)seed {
    return [seed dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)tokenForData:(NSData *)tokenData {
    NSMutableString *token = [NSMutableString stringWithCapacity:tokenData.length * 2];
    const uint8_t *bytes = (const uint8_t *)tokenData.bytes;
    for (NSUInteger i = 0; i < tokenData.length; ++i) {
        [token appendFormat:@"%02hhx", bytes[i]];
    }
    return token;
}

- (void)prepareRegistrationServerWithStatusCode:(NSInteger)statusCode tokens:(NSArray<NSData *> *)tokens {
    [self prepareRegistrationForTokens:tokens transport:^{
        self.serverStatusCode = statusCode;
        self.serverHoldsReplies = YES;
        self.heldReplies = [NSMutableArray array];
        self.answerCodes = [NSMapTable strongToStrongObjectsMapTable];
        self.registerAttempts = [NSMutableArray array];

        __weak typeof(self) wSelf = self;
        self.requestManagerMock = OCMPartialMock([PWNetworkModule module].requestManager);
        OCMStub([self.requestManagerMock sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
            __unsafe_unretained PWRequest *request;
            __unsafe_unretained void (^completion)(NSError *);
            [invocation getArgument:&request atIndex:2];
            [invocation getArgument:&completion atIndex:3];
            [wSelf serverReceivedRequest:request completion:completion];
        });
    }];
}

- (void)prepareRegistrationSessionWithTokens:(NSArray<NSData *> *)tokens statusForBody:(NSInteger (^)(NSDictionary *body))statusForBody {
    __weak typeof(self) wSelf = self;
    [self prepareRegistrationSessionWithTokens:tokens replyForBody:^(NSDictionary *body, NSURL *url, PWSessionReply reply) {
        [wSelf replyFromPushwoosh:reply url:url statusCode:statusForBody(body)];
    }];
}

/// Answers registerDevice behind the real request manager, so the request goes through its serialization.
- (void)prepareRegistrationSessionWithTokens:(NSArray<NSData *> *)tokens replyForBody:(void (^)(NSDictionary *body, NSURL *url, PWSessionReply reply))replyForBody {
    [self prepareRegistrationForTokens:tokens transport:^{
        PWRequestManager *requestManager = [PWNetworkModule module].requestManager;
        self.savedSession = requestManager.session;
        self.savedRetrySession = requestManager.retrySession;
        self.sessionTasks = [NSMutableArray array];

        __weak typeof(self) wSelf = self;
        self.sessionMock = OCMClassMock([NSURLSession class]);
        OCMStub([self.sessionMock dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
            __unsafe_unretained NSURLRequest *urlRequest;
            __unsafe_unretained void (^handler)(NSData *, NSURLResponse *, NSError *);
            [invocation getArgument:&urlRequest atIndex:2];
            [invocation getArgument:&handler atIndex:3];
            __unsafe_unretained id task = [wSelf sessionReceivedRequest:urlRequest handler:handler replyForBody:replyForBody];
            [invocation setReturnValue:&task];
        });
        requestManager.session = self.sessionMock;
        requestManager.retrySession = self.sessionMock;
    }];
}

- (void)prepareRegistrationForTokens:(NSArray<NSData *> *)tokens transport:(void (^)(void))installTransport {
    _savedAppCode = [PWPreferences preferences].appCode;
    _savedPushToken = [PWPreferences preferences].pushToken;
    _savedLastRegTime = [PWPreferences preferences].lastRegTime;
    _savedLastStatusMask = [PWPreferences preferences].lastStatusMask;
    _savedLanguage = [PWPreferences preferences].language;
    _savedActiveApplicationRecord = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_ACTIVE_APPLICATION"] copy];
    _savedDelegate = [PWManagerBridge shared].delegate;
    _savedCompat = [PWPlatformModule module].notificationManagerCompat;

    _compatMock = OCMClassMock([PWNotificationManagerCompat class]);
    OCMStub([_compatMock getRemoteNotificationStatusWithCompletion:([OCMArg invokeBlockWithArgs:@{}, nil])]);
    [PWPlatformModule module].notificationManagerCompat = _compatMock;

    NSMutableSet<NSString *> *serverTokens = [NSMutableSet set];
    for (NSData *token in tokens) {
        [serverTokens addObject:[self tokenForData:token]];
    }
    _serverTokens = serverTokens;
    _registerBodies = [NSMutableArray array];
    installTransport();

    [PWPreferences preferences].appCode = @"T1108-00001";
    [PWPreferences preferences].pushToken = [self tokenForData:tokens.firstObject];
    [PWPreferences preferences].lastRegTime = nil;
    [[PWPreferences preferences] setCustomTags:nil];

    _delegateRecorder = [PWRegistrationDelegateRecorder new];
    [PWManagerBridge shared].delegate = _delegateRecorder;
}

- (void)restoreRegistrationServer {
    [_heldReplies removeAllObjects];
    [_answerCodes removeAllObjects];
    [PWManagerBridge shared].delegate = _savedDelegate;
    [[PWPreferences preferences] setLanguage:_savedLanguage];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    [PWPreferences preferences].appCode = _savedAppCode;
    if (_savedActiveApplicationRecord) {
        [[NSUserDefaults standardUserDefaults] setObject:_savedActiveApplicationRecord forKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    [PWPreferences preferences].pushToken = _savedPushToken;
    [PWPreferences preferences].lastStatusMask = _savedLastStatusMask;
    [PWPreferences preferences].lastRegTime = _savedLastRegTime;
    [[PWPreferences preferences] setCustomTags:nil];
    [PWPlatformModule module].notificationManagerCompat = _savedCompat;
    [_compatMock stopMocking];
    [_requestManagerMock stopMocking];
    _requestManagerMock = nil;
    if (_sessionMock) {
        [PWNetworkModule module].requestManager.session = _savedSession;
        [PWNetworkModule module].requestManager.retrySession = _savedRetrySession;
        [_sessionMock stopMocking];
        _sessionMock = nil;
    }
}

- (void)serverReceivedRequest:(PWRequest *)request completion:(void (^)(NSError *))completion {
    if (![request isKindOfClass:[PWRegisterDeviceRequest class]] ||
        ![_serverTokens containsObject:((PWRegisterDeviceRequest *)request).token]) {
        return;
    }

    [_registerAttempts addObject:request];
    [_registerBodies addObject:[request requestDictionary] ?: @{}];

    void (^reply)(NSError *) = [completion copy];
    NSNumber *answerCode = [_answerCodes objectForKey:request];

    if (_serverHoldsReplies && answerCode == nil) {
        [_heldReplies addObject:@[ request, reply ]];
        return;
    }

    NSInteger statusCode = answerCode ? answerCode.integerValue : _serverStatusCode;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self answerRequest:request reply:reply statusCode:statusCode];
    });
}

- (id)sessionReceivedRequest:(NSURLRequest *)urlRequest handler:(PWSessionReply)handler replyForBody:(void (^)(NSDictionary *body, NSURL *url, PWSessionReply reply))replyForBody {
    id task = OCMClassMock([NSURLSessionDataTask class]);
    [_sessionTasks addObject:task];

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:urlRequest.HTTPBody ?: [NSData data] options:0 error:nil];
    NSDictionary *body = json[@"request"] ?: json;
    if (![urlRequest.URL.lastPathComponent isEqualToString:@"registerDevice"] ||
        ![_serverTokens containsObject:body[@"push_token"]]) {
        return task;
    }

    [_registerBodies addObject:body];
    NSURL *url = urlRequest.URL;
    PWSessionReply reply = [handler copy];
    OCMStub([task resume]).andDo(^(NSInvocation *invocation) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            replyForBody(body, url, reply);
        });
    });
    return task;
}

- (void)replyFromPushwoosh:(PWSessionReply)reply url:(NSURL *)url statusCode:(NSInteger)statusCode {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{ @"status_code": @(statusCode), @"status_message": statusCode == 200 ? @"OK" : @"Rejected", @"response": @{} } options:0 error:nil];
    reply(data, response, nil);
}

- (void)answerRequest:(PWRequest *)request reply:(void (^)(NSError *))reply statusCode:(NSInteger)statusCode {
    request.httpCode = statusCode;
    reply(statusCode == 200 ? nil : [NSError errorWithDomain:@"PWTestServer" code:statusCode userInfo:nil]);
}

- (void)releaseHeldReplies {
    _serverHoldsReplies = NO;
    NSArray<NSArray *> *replies = [_heldReplies copy];
    [_heldReplies removeAllObjects];
    for (NSArray *held in replies) {
        [self answerRequest:held[0] reply:held[1] statusCode:_serverStatusCode];
    }
}

- (void)releaseHeldRepliesOf:(PWRequest *)request statusCode:(NSInteger)statusCode {
    [_answerCodes setObject:@(statusCode) forKey:request];
    NSArray<NSArray *> *replies = [_heldReplies copy];
    for (NSArray *held in replies) {
        if (held[0] == request) {
            [_heldReplies removeObjectIdenticalTo:held];
            [self answerRequest:request reply:held[1] statusCode:statusCode];
        }
    }
}

- (void)assertTagsOfFailedRegistrationAreSentWithNextRegistration:(NSDictionary *)tags tokenData:(NSData *)tokenData {
    NSString *token = [self tokenForData:tokenData];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    XCTestExpectation *failed = [self expectationWithDescription:@"failed registration"];
    __block NSError *failure = nil;
    [[PWPreferences preferences] setCustomTags:tags];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        failure = error;
        [failed fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self waitForExpectations:@[ failed ] timeout:5];

    XCTAssertNotNil(failure);

    NSUInteger sentBefore = self.registerBodies.count;
    XCTestExpectation *outcome = [self expectationWithDescription:@"next registration outcome"];
    __block NSString *receivedToken = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        receivedToken = registeredToken;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertEqualObjects(receivedToken, token);
    XCTAssertEqual(self.registerBodies.count, sentBefore + 1);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"tags"], tags);
}

- (void)assertTagsOfRejectedRegistrationDoNotBlockNextRegistration:(NSDictionary *)tags tokenData:(NSData *)tokenData {
    NSString *token = [self tokenForData:tokenData];
    PWPushNotificationsManagerCommon *manager = [self newRegistrationManager];

    XCTestExpectation *rejected = [self expectationWithDescription:@"rejected registration"];
    __block NSError *rejectionError = nil;
    [[PWPreferences preferences] setCustomTags:tags];
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        rejectionError = error;
        [rejected fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self waitForExpectations:@[ rejected ] timeout:5];

    XCTAssertNotNil(rejectionError);
    XCTAssertEqualObjects(self.registerBodies.lastObject[@"tags"], tags);

    NSUInteger sentBefore = self.registerBodies.count;
    XCTestExpectation *outcome = [self expectationWithDescription:@"next registration outcome"];
    __block NSString *receivedToken = nil;
    __block NSError *receivedError = nil;
    [manager registerForPushNotificationsWithCompletion:^(NSString *registeredToken, NSError *error) {
        receivedToken = registeredToken;
        receivedError = error;
        [outcome fulfill];
    }];
    [manager handlePushRegistration:tokenData];
    [self waitForExpectations:@[ outcome ] timeout:5];

    XCTAssertNil(receivedError);
    XCTAssertEqualObjects(receivedToken, token);
    XCTAssertEqual(self.registerBodies.count, sentBefore + 1);
    XCTAssertNil(self.registerBodies.lastObject[@"tags"]);
}

- (void)replyWithPage:(PWSessionReply)reply url:(NSURL *)url statusCode:(NSInteger)statusCode {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:@{ @"Content-Type": @"text/html" }];
    reply([@"<html><body>Request rejected</body></html>" dataUsingEncoding:NSUTF8StringEncoding], response, nil);
}

- (NSUInteger)attemptsOf:(PWRequest *)request {
    NSUInteger attempts = 0;
    for (PWRequest *attempt in _registerAttempts) {
        attempts += attempt == request ? 1 : 0;
    }
    return attempts;
}

- (NSUInteger)registrationsSent {
    NSMutableArray<PWRequest *> *registrations = [NSMutableArray array];
    for (PWRequest *attempt in _registerAttempts) {
        if ([registrations indexOfObjectIdenticalTo:attempt] == NSNotFound) {
            [registrations addObject:attempt];
        }
    }
    return registrations.count;
}

- (PWPushNotificationsManagerCommon *)newRegistrationManager {
    PWPushNotificationsManagerCommon *manager = [[PWPushNotificationsManager alloc] init];
    manager.sessionRetry.retryDelaysSeconds = @[ @0, @0, @0 ];
    return manager;
}

- (void)drainMainQueue {
    XCTestExpectation *drained = [self expectationWithDescription:@"main queue"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [drained fulfill];
    });
    [self waitForExpectations:@[ drained ] timeout:5];
}

- (void)waitForDelegate:(BOOL (^)(PWRegistrationDelegateRecorder *delegate))condition {
    PWRegistrationDelegateRecorder *delegate = _delegateRecorder;
    NSPredicate *reached = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return condition(delegate);
    }];
    [self waitForExpectations:@[ [[XCTNSPredicateExpectation alloc] initWithPredicate:reached object:nil] ] timeout:5];
}

- (void)waitUntil:(BOOL (^)(void))condition {
    NSPredicate *reached = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return condition();
    }];
    [self waitForExpectations:@[ [[XCTNSPredicateExpectation alloc] initWithPredicate:reached object:nil] ] timeout:5];
}

@end

#pragma clang diagnostic pop
