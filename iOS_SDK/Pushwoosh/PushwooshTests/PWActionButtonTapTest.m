//
//  PWActionButtonTapTest.m
//  PushwooshTests
//
//  Created by André Kis on 08.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UserNotifications/UserNotifications.h>

#import "PushwooshFramework.h"
#import "PWPushNotificationsManager.h"
#import "PWUserNotificationCenterDelegate.h"
#import "PWDataManager.h"
#import "PWNetworkModule.h"
#import "PWRequestManagerMock.h"
#import "PWPushStatRequest.h"
#import "PWBundleMock.h"
#import "PWConfig.h"
#import "PWActionButton.h"
#import "PWActionButtonsParser.h"
#import <PushwooshCore/PWManagerBridge.h>

#if TARGET_OS_IOS

static NSString * const kButtonsA = @"[{\"id\":\"open_app\",\"label\":\"Open\",\"action\":\"open\"},"
                                     "{\"id\":\"site\",\"label\":\"Website\",\"action\":\"url\",\"url\":\"https://www.pushwoosh.com\"},"
                                     "{\"id\":\"sale\",\"label\":\"Sale\",\"action\":\"deeplink\",\"url\":\"pushwoosh://sale\"}]";

static NSDictionary *PWPushA(void) {
    return @{ @"aps" : @{ @"alert" : @"hi" },
              @"l" : @"pushwoosh://product/n6fx",
              @"p" : @"hashA",
              @"pw_msg" : @"1",
              @"pw_buttons" : kButtonsA };
}

static NSDictionary *PWPushWithLegacyCategory(void) {
    return @{ @"aps" : @{ @"alert" : @"hi", @"category" : @"9301" },
              @"l" : @"pushwoosh://product/n6fx",
              @"p" : @"hashLegacy",
              @"pw_msg" : @"1" };
}

static NSDictionary *PWPushWithRichMedia(void) {
    return @{ @"aps" : @{ @"alert" : @"hi" },
              @"rm" : @{ @"url" : @"https://richmedia.example/page.zip" },
              @"p" : @"hashRich",
              @"pw_msg" : @"1",
              @"pw_buttons" : kButtonsA };
}

/// Counts the opened callbacks and remembers what each callback told the application.
@interface PWButtonSpyDelegate : NSObject

@property (nonatomic) NSUInteger messageOpenedCount;
@property (nonatomic, copy) NSString *lastOpenedActionIdentifier;
@property (nonatomic) BOOL lastOpenedForeground;
@property (nonatomic) NSUInteger pushAcceptedCount;
@property (nonatomic) BOOL lastAcceptedOnStart;
@property (nonatomic) NSUInteger pushReceivedCount;
@property (nonatomic) BOOL lastReceivedOnStart;
@property (nonatomic) BOOL lastReceivedForeground;

@end

@implementation PWButtonSpyDelegate

- (void)pushwoosh:(id)pushwoosh onMessageOpened:(PWMessage *)message {
    self.messageOpenedCount++;
    self.lastOpenedActionIdentifier = message.actionIdentifier;
    self.lastOpenedForeground = message.foregroundMessage;
}

- (void)onPushAccepted:(id)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart {
    self.pushAcceptedCount++;
    self.lastAcceptedOnStart = onStart;
}

- (void)onPushReceived:(id)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart {
    self.pushReceivedCount++;
    self.lastReceivedOnStart = onStart;
}

- (void)pushwoosh:(id)pushwoosh onMessageReceived:(PWMessage *)message {
    self.lastReceivedForeground = message.foregroundMessage;
}

@end

@interface PWUserNotificationCenterDelegate (ActionButtonTapTest)

@property (nonatomic) NSTimeInterval actionButtonResponseTimeout;

@end

@interface PWPushNotificationsManager (ActionButtonTapTest)

- (void)didFinishLaunching:(NSNotification *)notification;
- (void)openDeepLinkForUserInfo:(NSDictionary *)userInfo;
- (void)openActionButtonUrl:(NSURL *)url;
- (BOOL)presentRichContentForUserInfo:(NSDictionary *)userInfo;

@end

@interface PWActionButtonTapTest : XCTestCase

@property (nonatomic, strong) PWPushNotificationsManager *manager;
@property (nonatomic, strong) id managerMock;
@property (nonatomic, strong) PWUserNotificationCenterDelegate *centerDelegate;
@property (nonatomic, strong) PWButtonSpyDelegate *spy;
@property (nonatomic, strong) PWRequestManagerMock *requestManager;
@property (nonatomic, strong) NSMutableArray<PWPushStatRequest *> *pushStats;
@property (nonatomic, strong) NSMutableArray<NSURL *> *openedButtonUrls;
@property (nonatomic) NSUInteger pushLinkOpenCount;
@property (nonatomic) NSUInteger richMediaCount;
@property (nonatomic) BOOL appInBackground;
@property (nonatomic) UIApplicationState applicationState;

@property (nonatomic, strong) id applicationMock;
@property (nonatomic, strong) id centerMock;
@property (nonatomic, strong) NSMutableArray *helperMocks;
@property (nonatomic, strong) PWRequestManager *originalRequestManager;
@property (nonatomic, strong) PWDataManager *originalDataManager;
@property (nonatomic, strong) PWPushNotificationsManager *originalPushManager;
@property (nonatomic, weak) id originalDelegate;
@property (nonatomic) BOOL originalShowAlert;
@property (nonatomic, copy) NSDictionary *originalLaunchNotification;

@end

@implementation PWActionButtonTapTest

- (void)setUp {
    [super setUp];

    __weak typeof(self) weakSelf = self;
    _applicationState = UIApplicationStateActive;
    _applicationMock = OCMClassMock([UIApplication class]);
    OCMStub([_applicationMock sharedApplication]).andReturn(_applicationMock);
    OCMStub([_applicationMock applicationState]).andDo(^(NSInvocation *invocation) {
        UIApplicationState state = weakSelf.applicationState;
        [invocation setReturnValue:&state];
    });

    _pushStats = [NSMutableArray array];
    _openedButtonUrls = [NSMutableArray array];
    _originalRequestManager = [PWNetworkModule module].requestManager;
    _requestManager = [PWRequestManagerMock new];
    _requestManager.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWPushStatRequest class]]) {
            [weakSelf.pushStats addObject:(PWPushStatRequest *)request];
        }
    };
    [PWNetworkModule module].requestManager = _requestManager;

    _originalDataManager = [PWManagerBridge shared].dataManager;
    [PWManagerBridge shared].dataManager = [PWDataManager new];

    _originalDelegate = [PWManagerBridge shared].delegate;
    _spy = [PWButtonSpyDelegate new];
    [PWManagerBridge shared].delegate = _spy;

    _originalShowAlert = [PWManagerBridge shared].showPushnotificationAlert;
    [PWManagerBridge shared].showPushnotificationAlert = YES;

    _originalLaunchNotification = [PWManagerBridge shared].launchNotification;
    [PWManagerBridge shared].launchNotification = nil;

    _originalPushManager = [PWManagerBridge shared].pushNotificationManager;
    _helperMocks = [NSMutableArray array];
    _centerMock = OCMClassMock([UNUserNotificationCenter class]);
    [self installManager];
}

- (void)tearDown {
    [PWManagerBridge shared].pushNotificationManager = _originalPushManager;
    [PWManagerBridge shared].delegate = _originalDelegate;
    [PWManagerBridge shared].showPushnotificationAlert = _originalShowAlert;
    [PWManagerBridge shared].launchNotification = _originalLaunchNotification;
    [PWManagerBridge shared].dataManager = _originalDataManager;
    [PWNetworkModule module].requestManager = _originalRequestManager;
    [_managerMock stopMocking];
    [_centerMock stopMocking];
    for (id mock in _helperMocks) {
        [mock stopMocking];
    }
    [_applicationMock stopMocking];
    [super tearDown];
}

#pragma mark - Fixture

/// Builds the manager the way the SDK does, then takes over the seams the tests drive: the app state
/// and the three destinations, each of which is a timer that cannot be awaited reliably here.
- (void)installManager {
    [_managerMock stopMocking];
    _manager = [[PWPushNotificationsManager alloc] initWithConfig:[[PWConfig alloc] initWithBundle:[PWBundleMock new]]];
    _managerMock = OCMPartialMock(_manager);
    __weak typeof(self) weakSelf = self;
    OCMStub([_managerMock isAppInBackground]).andDo(^(NSInvocation *invocation) {
        BOOL inBackground = weakSelf.appInBackground;
        [invocation setReturnValue:&inBackground];
    });
    OCMStub([_managerMock openDeepLinkForUserInfo:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        weakSelf.pushLinkOpenCount++;
    });
    OCMStub([_managerMock presentRichContentForUserInfo:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        weakSelf.richMediaCount++;
        BOOL presented = YES;
        [invocation setReturnValue:&presented];
    });
    OCMStub([_managerMock openActionButtonUrl:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSURL *url = nil;
        [invocation getArgument:&url atIndex:2];
        [weakSelf.openedButtonUrls addObject:url];
    });
    _centerDelegate = [[PWUserNotificationCenterDelegate alloc] initWithNotificationManager:_manager];
    [PWManagerBridge shared].pushNotificationManager = _manager;
}

- (id)remoteNotificationWithUserInfo:(NSDictionary *)userInfo {
    id trigger = OCMClassMock([UNPushNotificationTrigger class]);
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.userInfo = userInfo;
    id request = OCMClassMock([UNNotificationRequest class]);
    OCMStub([request trigger]).andReturn(trigger);
    OCMStub([request content]).andReturn(content);
    OCMStub([request identifier]).andReturn(@"test-id");
    id notification = OCMClassMock([UNNotification class]);
    OCMStub([notification request]).andReturn(request);
    [_helperMocks addObjectsFromArray:@[ trigger, request, notification ]];
    return notification;
}

/// The notification the SDK re-publishes locally while the application is open: same content, plus the
/// pw_push marker, no push trigger.
- (id)foregroundNotificationWithUserInfo:(NSDictionary *)userInfo {
    NSMutableDictionary *republished = [userInfo mutableCopy];
    republished[@"pw_push"] = @(YES);

    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.userInfo = republished;
    id request = OCMClassMock([UNNotificationRequest class]);
    OCMStub([request trigger]).andReturn(nil);
    OCMStub([request content]).andReturn(content);
    OCMStub([request identifier]).andReturn(@"test-id");
    id notification = OCMClassMock([UNNotification class]);
    OCMStub([notification request]).andReturn(request);
    [_helperMocks addObjectsFromArray:@[ request, notification ]];
    return notification;
}

/// What iOS does when the user taps a button under the notification, or the notification itself.
- (void)tapNotification:(id)notification action:(NSString *)actionIdentifier {
    id response = OCMClassMock([UNNotificationResponse class]);
    OCMStub([response notification]).andReturn(notification);
    OCMStub([response actionIdentifier]).andReturn(actionIdentifier);
    [_helperMocks addObject:response];
    [_centerDelegate userNotificationCenter:_centerMock
             didReceiveNotificationResponse:response
                      withCompletionHandler:^{}];
    [self settle];
}

- (void)tap:(NSDictionary *)userInfo action:(NSString *)actionIdentifier {
    [self tapNotification:[self remoteNotificationWithUserInfo:userInfo] action:actionIdentifier];
}

- (void)tapInForeground:(NSDictionary *)userInfo action:(NSString *)actionIdentifier {
    [self tapNotification:[self foregroundNotificationWithUserInfo:userInfo] action:actionIdentifier];
}

/// The SDK delivers its callbacks global queue → main queue; the drain starts once that block has had
/// time to finish.
- (void)settle {
    XCTestExpectation *settled = [self expectationWithDescription:@"async callbacks delivered"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [settled fulfill];
            });
        });
    });
    [self waitForExpectations:@[ settled ] timeout:2];
}

- (NSArray<NSString *> *)sentButtonIds {
    NSMutableArray *ids = [NSMutableArray array];
    for (PWPushStatRequest *request in _pushStats) {
        [ids addObject:request.requestDictionary[@"button_id"] ?: [NSNull null]];
    }
    return ids;
}

#pragma mark - The button replaces the push's own destinations

/// Verifies an open button opens nothing of the push's own and still counts as one open naming it.
- (void)testOpenButtonOpensNothingAndCountsAsAnOpen {
    self.appInBackground = YES;

    [self tap:PWPushA() action:@"open_app"];

    XCTAssertEqual(_pushLinkOpenCount, 0);
    XCTAssertEqual(_openedButtonUrls.count, 0);
    XCTAssertEqual(_pushStats.count, 1);
    XCTAssertEqualObjects([self sentButtonIds], (@[ @"open_app" ]));
    XCTAssertEqualObjects(_pushStats.firstObject.requestDictionary[@"hash"], @"hashA");
}

/// Verifies a url button opens its own url and not the push's link.
- (void)testUrlButtonOpensItsOwnUrl {
    self.appInBackground = YES;

    [self tap:PWPushA() action:@"site"];

    XCTAssertEqual(_pushLinkOpenCount, 0);
    XCTAssertEqualObjects(_openedButtonUrls, (@[ [NSURL URLWithString:@"https://www.pushwoosh.com"] ]));
    XCTAssertEqualObjects([self sentButtonIds], (@[ @"site" ]));
}

/// Verifies a deeplink button opens its own url the same way, and not the push's link.
- (void)testDeeplinkButtonOpensItsOwnUrl {
    self.appInBackground = YES;

    [self tap:PWPushA() action:@"sale"];

    XCTAssertEqual(_pushLinkOpenCount, 0);
    XCTAssertEqualObjects(_openedButtonUrls, (@[ [NSURL URLWithString:@"pushwoosh://sale"] ]));
    XCTAssertEqualObjects([self sentButtonIds], (@[ @"sale" ]));
}

/// Verifies a button does not open the push's rich media either.
- (void)testButtonDoesNotPresentThePushRichMedia {
    self.appInBackground = YES;

    [self tap:PWPushWithRichMedia() action:@"open_app"];

    XCTAssertEqual(_richMediaCount, 0);
}

/// Verifies the button id reaches application code through the existing opened callback.
- (void)testOpenedCallbackCarriesTheButtonId {
    self.appInBackground = YES;

    [self tap:PWPushA() action:@"sale"];

    XCTAssertEqual(_spy.messageOpenedCount, 1);
    XCTAssertEqualObjects(_spy.lastOpenedActionIdentifier, @"sale");
}

/// Verifies a button under the banner the SDK re-publishes while the application is open behaves the
/// same: that tap arrives as a local pw_push notification, not as a remote one.
- (void)testButtonTappedOnTheForegroundBannerBehavesTheSame {
    self.appInBackground = NO;

    [self tapInForeground:PWPushA() action:@"sale"];

    XCTAssertEqual(_pushLinkOpenCount, 0);
    XCTAssertEqualObjects(_openedButtonUrls, (@[ [NSURL URLWithString:@"pushwoosh://sale"] ]));
    XCTAssertEqual(_pushStats.count, 1);
    XCTAssertEqualObjects([self sentButtonIds], (@[ @"sale" ]));
    XCTAssertEqualObjects(_spy.lastOpenedActionIdentifier, @"sale");
}

/// Verifies a tap on that re-published banner itself still opens the push's own link.
- (void)testPlainTapOnTheForegroundBannerOpensThePushLink {
    self.appInBackground = NO;

    [self tapInForeground:PWPushA() action:UNNotificationDefaultActionIdentifier];

    XCTAssertEqual(_pushLinkOpenCount, 1);
    XCTAssertEqual(_openedButtonUrls.count, 0);
    XCTAssertNil(_pushStats.firstObject.requestDictionary[@"button_id"]);
}

#pragma mark - A tap on the notification itself is unchanged

/// Verifies a tap on the notification body still opens the push's own link and names no button.
- (void)testPlainTapOpensThePushLinkAndNamesNoButton {
    self.appInBackground = YES;

    [self tap:PWPushA() action:UNNotificationDefaultActionIdentifier];

    XCTAssertEqual(_pushLinkOpenCount, 1);
    XCTAssertEqual(_openedButtonUrls.count, 0);
    XCTAssertEqual(_pushStats.count, 1);
    XCTAssertNil(_pushStats.firstObject.requestDictionary[@"button_id"]);
}

/// Verifies a button of a category the application registered in its own code behaves as before the
/// update: it opens the push's link and names no button.
- (void)testLegacyCategoryButtonKeepsOpeningThePushLink {
    self.appInBackground = YES;

    [self tap:PWPushWithLegacyCategory() action:@"legacy_button"];

    XCTAssertEqual(_pushLinkOpenCount, 1);
    XCTAssertEqual(_openedButtonUrls.count, 0);
    XCTAssertNil(_pushStats.firstObject.requestDictionary[@"button_id"]);
}

#pragma mark - The pre-handling switch

/// Verifies Pushwoosh_PREHANDLE_URL_NOTIFICATIONS = NO keeps the SDK from opening the button's url,
/// while the button id still reaches application code.
- (void)testPrehandleDisabledDoesNotOpenTheButtonUrl {
    id configMock = OCMPartialMock([PWConfig config]);
    OCMStub([configMock preHandleNotificationsWithUrl]).andReturn(NO);
    [_helperMocks addObject:configMock];
    self.appInBackground = YES;

    [self tap:PWPushA() action:@"site"];

    XCTAssertEqual(_openedButtonUrls.count, 0);
    XCTAssertEqualObjects(_spy.lastOpenedActionIdentifier, @"site");
    XCTAssertEqualObjects([self sentButtonIds], (@[ @"site" ]));
}

/// Verifies Pushwoosh_PREHANDLE_URL_NOTIFICATIONS = NO keeps the SDK from opening the button's
/// deeplink too, while the button id still reaches application code.
- (void)testPrehandleDisabledDoesNotOpenTheButtonDeeplink {
    id configMock = OCMPartialMock([PWConfig config]);
    OCMStub([configMock preHandleNotificationsWithUrl]).andReturn(NO);
    [_helperMocks addObject:configMock];
    self.appInBackground = YES;

    [self tap:PWPushA() action:@"sale"];

    XCTAssertEqual(_openedButtonUrls.count, 0);
    XCTAssertEqualObjects(_spy.lastOpenedActionIdentifier, @"sale");
    XCTAssertEqualObjects([self sentButtonIds], (@[ @"sale" ]));
}

#pragma mark - Background buttons

/// Taps without draining the callbacks and hands the system completion handler to the test, so the
/// ordering of that handler against the statistics can be observed.
- (void)tapWithoutSettling:(NSDictionary *)userInfo
                    action:(NSString *)actionIdentifier
                  finished:(void (^)(void))finished {
    id notification = [self remoteNotificationWithUserInfo:userInfo];
    id response = OCMClassMock([UNNotificationResponse class]);
    OCMStub([response notification]).andReturn(notification);
    OCMStub([response actionIdentifier]).andReturn(actionIdentifier);
    [_helperMocks addObject:response];
    [_centerDelegate userNotificationCenter:_centerMock
             didReceiveNotificationResponse:response
                      withCompletionHandler:finished];
}

- (NSDictionary *)pushB {
    return @{ @"aps" : @{ @"alert" : @"hi" },
              @"l" : @"pushwoosh://product/n6fx",
              @"p" : @"hashB",
              @"pw_msg" : @"1",
              @"pw_buttons" : @"[{\"id\":\"open_app\",\"label\":\"Open\",\"action\":\"open\"},"
                               "{\"id\":\"cancel_order\",\"label\":\"Cancel\",\"action\":\"custom\",\"style\":\"destructive\"}]" };
}

/// Verifies the system completion handler of a background button runs only after the open statistics
/// were answered, so the process is not torn down with the request still in flight.
- (void)testBackgroundButtonFinishesAfterTheStatisticsAreAnswered {
    self.appInBackground = YES;
    self.requestManager.deferredMethods = [NSSet setWithObject:@"pushStat"];

    __block BOOL finished = NO;
    [self tapWithoutSettling:[self pushB] action:@"cancel_order" finished:^{
        finished = YES;
    }];
    [self settle];

    XCTAssertEqual(_pushStats.count, 1);
    XCTAssertFalse(finished);

    [self.requestManager releaseDeferredRequests];
    [self settle];

    XCTAssertTrue(finished);
    XCTAssertEqualObjects([self sentButtonIds], (@[ @"cancel_order" ]));
}

/// Verifies a background button does not open the push's link and still reports the open to the
/// application with the button id.
- (void)testBackgroundButtonOpensNothingAndReportsTheOpen {
    self.appInBackground = YES;

    [self tap:[self pushB] action:@"cancel_order"];

    XCTAssertEqual(_pushLinkOpenCount, 0);
    XCTAssertEqual(_openedButtonUrls.count, 0);
    XCTAssertEqual(_spy.messageOpenedCount, 1);
    XCTAssertEqualObjects(_spy.lastOpenedActionIdentifier, @"cancel_order");
}

/// Verifies a foreground button does not make the system wait: its handler runs straight away.
- (void)testForegroundButtonFinishesImmediately {
    self.appInBackground = YES;
    self.requestManager.deferredMethods = [NSSet setWithObject:@"pushStat"];

    __block BOOL finished = NO;
    [self tapWithoutSettling:[self pushB] action:@"open_app" finished:^{
        finished = YES;
    }];

    XCTAssertTrue(finished);

    [self.requestManager releaseDeferredRequests];
    [self settle];
}

/// Verifies a plain tap finishes immediately, exactly as before this feature.
- (void)testPlainTapFinishesImmediately {
    self.appInBackground = YES;
    self.requestManager.deferredMethods = [NSSet setWithObject:@"pushStat"];

    __block BOOL finished = NO;
    [self tapWithoutSettling:PWPushA() action:UNNotificationDefaultActionIdentifier finished:^{
        finished = YES;
    }];

    XCTAssertTrue(finished);

    [self.requestManager releaseDeferredRequests];
    [self settle];
}

/// Verifies the response still ends when the open statistics never answer: the watchdog releases the
/// system completion handler rather than leaving the background launch hanging on it.
- (void)testBackgroundButtonFinishesWhenTheStatisticsNeverAnswer {
    self.appInBackground = YES;
    self.requestManager.deferredMethods = [NSSet setWithObject:@"pushStat"];
    _centerDelegate.actionButtonResponseTimeout = 0.05;

    XCTestExpectation *released = [self expectationWithDescription:@"watchdog released the response"];
    released.assertForOverFulfill = NO;
    __block NSUInteger finishCount = 0;
    [self tapWithoutSettling:[self pushB] action:@"cancel_order" finished:^{
        finishCount++;
        [released fulfill];
    }];

    XCTAssertEqual(finishCount, 0);

    [self waitForExpectations:@[ released ] timeout:2];

    XCTAssertEqual(finishCount, 1);

    [self.requestManager releaseDeferredRequests];
    [self settle];
}

/// Verifies the system completion handler runs exactly once when both ends fire — the watchdog releases
/// the response and the statistics answer afterwards. iOS treats a second call as a programming error.
- (void)testBackgroundButtonFinishesExactlyOnce {
    self.appInBackground = YES;
    self.requestManager.deferredMethods = [NSSet setWithObject:@"pushStat"];
    _centerDelegate.actionButtonResponseTimeout = 0.05;

    XCTestExpectation *released = [self expectationWithDescription:@"watchdog released the response"];
    released.assertForOverFulfill = NO;
    __block NSUInteger finishCount = 0;
    [self tapWithoutSettling:[self pushB] action:@"cancel_order" finished:^{
        finishCount++;
        [released fulfill];
    }];
    [self waitForExpectations:@[ released ] timeout:2];

    XCTAssertEqual(finishCount, 1);

    [self.requestManager releaseDeferredRequests];
    [self settle];

    XCTAssertEqual(finishCount, 1);
}

#pragma mark - What counts as opening the application

/// Verifies a background button is not remembered as the push that launched the application, while its
/// open statistic and the opened callback still name the button.
- (void)testBackgroundButtonIsNotTheLaunchNotification {
    self.appInBackground = YES;

    [self tap:[self pushB] action:@"cancel_order"];

    XCTAssertNil([PWManagerBridge shared].launchNotification);
    XCTAssertEqualObjects([self sentButtonIds], (@[ @"cancel_order" ]));
    XCTAssertEqualObjects(_spy.lastOpenedActionIdentifier, @"cancel_order");
}

/// Verifies a button that opens the application is still remembered as the launch notification.
- (void)testForegroundButtonIsTheLaunchNotification {
    self.appInBackground = YES;

    [self tap:[self pushB] action:@"open_app"];

    XCTAssertEqualObjects([PWManagerBridge shared].launchNotification[@"p"], @"hashB");
}

/// Verifies a button of the push's aps.category is still remembered as the launch notification.
- (void)testLegacyCategoryButtonIsTheLaunchNotification {
    self.appInBackground = YES;

    [self tap:PWPushWithLegacyCategory() action:@"legacy_button"];

    XCTAssertEqualObjects([PWManagerBridge shared].launchNotification[@"p"], @"hashLegacy");
}

/// Verifies the accepted callback does not report a background button as the push that started the
/// application, while the opened message stays a background one and still names the button.
- (void)testBackgroundButtonIsNotReportedAsAStart {
    self.appInBackground = YES;

    [self tap:[self pushB] action:@"cancel_order"];

    XCTAssertEqual(_spy.pushAcceptedCount, 1);
    XCTAssertFalse(_spy.lastAcceptedOnStart);
    XCTAssertFalse(_spy.lastOpenedForeground);
    XCTAssertEqualObjects(_spy.lastOpenedActionIdentifier, @"cancel_order");
    XCTAssertEqualObjects([self sentButtonIds], (@[ @"cancel_order" ]));
}

/// Verifies a button that opens the application is still reported as a start.
- (void)testForegroundButtonIsReportedAsAStart {
    self.appInBackground = YES;

    [self tap:[self pushB] action:@"open_app"];

    XCTAssertTrue(_spy.lastAcceptedOnStart);
}

/// Verifies a button of the push's aps.category is still reported as a start.
- (void)testLegacyCategoryButtonIsReportedAsAStart {
    self.appInBackground = YES;

    [self tap:PWPushWithLegacyCategory() action:@"legacy_button"];

    XCTAssertTrue(_spy.lastAcceptedOnStart);
}

/// Verifies the received callback of a background button's response does not report a start either,
/// while the received message stays a background one.
- (void)testBackgroundButtonIsNotReportedAsAStartOnReceive {
    self.appInBackground = YES;

    [self tap:[self pushB] action:@"cancel_order"];

    XCTAssertEqual(_spy.pushReceivedCount, 1);
    XCTAssertFalse(_spy.lastReceivedOnStart);
    XCTAssertFalse(_spy.lastReceivedForeground);
}

/// Verifies a tap on the notification itself is still reported as a start on receive.
- (void)testPlainTapIsReportedAsAStartOnReceive {
    self.appInBackground = YES;

    [self tap:[self pushB] action:UNNotificationDefaultActionIdentifier];

    XCTAssertEqual(_spy.pushReceivedCount, 1);
    XCTAssertTrue(_spy.lastReceivedOnStart);
}

/// Verifies a button that opens the application and a button of the push's aps.category are still
/// reported as a start on receive.
- (void)testOpeningButtonsAreReportedAsAStartOnReceive {
    self.appInBackground = YES;

    [self tap:[self pushB] action:@"open_app"];
    XCTAssertTrue(_spy.lastReceivedOnStart);

    _spy.lastReceivedOnStart = NO;
    [self tap:PWPushWithLegacyCategory() action:@"legacy_button"];
    XCTAssertTrue(_spy.lastReceivedOnStart);
}

/// Verifies a background button that launched the killed application drops the push iOS put in the
/// launch options, so it is not reported as the launch notification later.
- (void)testBackgroundButtonOnColdStartIsNotTheLaunchNotification {
    [self launchWithRemoteNotification:[self pushB]];
    XCTAssertEqualObjects([PWManagerBridge shared].launchNotification[@"p"], @"hashB");
    self.appInBackground = YES;

    [self tap:[self pushB] action:@"cancel_order"];

    XCTAssertNil([PWManagerBridge shared].launchNotification);
    XCTAssertFalse(_spy.lastAcceptedOnStart);
}

/// Verifies a background button leaves alone a launch notification that belongs to another push.
- (void)testBackgroundButtonKeepsTheLaunchNotificationOfAnotherPush {
    [self launchWithRemoteNotification:PWPushA()];
    self.appInBackground = YES;

    [self tap:[self pushB] action:@"cancel_order"];

    XCTAssertEqualObjects([PWManagerBridge shared].launchNotification[@"p"], @"hashA");
}

/// What UIKit posts once the application finished launching because of a remote notification.
- (void)launchWithRemoteNotification:(NSDictionary *)userInfo {
    [self.manager didFinishLaunching:[NSNotification notificationWithName:UIApplicationDidFinishLaunchingNotification
                                                                   object:nil
                                                                 userInfo:@{ UIApplicationLaunchOptionsRemoteNotificationKey : userInfo }]];
}

#pragma mark - The one-second background delay

/// Verifies a background button's open statistic leaves at once while the application is not active: the
/// one-second delay of the ordinary path would outlive the response iOS is holding open.
- (void)testBackgroundButtonSendsTheStatisticsWithoutTheBackgroundDelay {
    self.appInBackground = YES;
    self.applicationState = UIApplicationStateBackground;
    self.requestManager.deferredMethods = [NSSet setWithObject:@"pushStat"];

    __block BOOL finished = NO;
    [self tapWithoutSettling:[self pushB] action:@"cancel_order" finished:^{
        finished = YES;
    }];

    XCTAssertEqual(_pushStats.count, 1);
    XCTAssertFalse(finished);

    [self.requestManager releaseDeferredRequests];
    [self settle];

    XCTAssertTrue(finished);
}

/// Verifies the ordinary open path keeps that delay for a non-active application: nothing has left yet at
/// the instant the response returns, exactly as before this feature.
- (void)testPlainTapKeepsTheBackgroundDelay {
    self.appInBackground = YES;
    self.applicationState = UIApplicationStateBackground;

    [self tapWithoutSettling:PWPushA() action:UNNotificationDefaultActionIdentifier finished:^{}];

    XCTAssertEqual(_pushStats.count, 0);
}

#pragma mark - The notification leaves the Notification Center

/// Verifies a button tap clears the notification it came from, so it does not linger after the user
/// has already answered it.
- (void)testButtonTapRemovesTheDeliveredNotification {
    self.appInBackground = YES;

    [self tap:PWPushA() action:@"sale"];

    OCMVerify([_centerMock removeDeliveredNotificationsWithIdentifiers:(@[ @"test-id" ])]);
}

/// Verifies a tap on the notification itself does not add a removal call of ours: iOS already clears it
/// and an application on the old path must see no new behaviour.
- (void)testPlainTapDoesNotRemoveTheNotificationItself {
    OCMReject([_centerMock removeDeliveredNotificationsWithIdentifiers:OCMOCK_ANY]);
    self.appInBackground = YES;

    [self tap:PWPushA() action:UNNotificationDefaultActionIdentifier];
}

@end

#endif
