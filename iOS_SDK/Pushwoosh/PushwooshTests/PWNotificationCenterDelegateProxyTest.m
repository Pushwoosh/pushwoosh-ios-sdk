#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UserNotifications/UserNotifications.h>

#import "PushwooshFramework.h"
#import "PWNotificationCenterDelegateProxy+Internal.h"
#import "PWUserNotificationCenterDelegate.h"
#import "PWPushNotificationsManager.h"

#if TARGET_OS_IOS

/// Spy client delegate that records each UNUserNotificationCenterDelegate callback.
@interface PWNCDPClientSpy : NSObject <UNUserNotificationCenterDelegate>

@property (nonatomic) NSUInteger willPresentCount;
@property (nonatomic) NSUInteger didReceiveResponseCount;
@property (nonatomic) NSUInteger openSettingsCount;
@property (nonatomic, strong) UNNotification *lastWillPresentNotification;
@property (nonatomic, strong) UNNotificationResponse *lastResponse;
@property (nonatomic, strong) UNNotification *lastOpenSettingsNotification;

@end

@implementation PWNCDPClientSpy

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    _willPresentCount++;
    _lastWillPresentNotification = notification;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
    _didReceiveResponseCount++;
    _lastResponse = response;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
   openSettingsForNotification:(UNNotification *)notification {
    _openSettingsCount++;
    _lastOpenSettingsNotification = notification;
}

@end

/// Minimal delegate that only implements openSettings — used to verify respondsToSelector filtering.
@interface PWNCDPOpenSettingsOnlyDelegate : NSObject <UNUserNotificationCenterDelegate>

@property (nonatomic) NSUInteger openSettingsCount;

@end

@implementation PWNCDPOpenSettingsOnlyDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
   openSettingsForNotification:(UNNotification *)notification {
    _openSettingsCount++;
}

@end

/// Delegate that DOES invoke the completion handler — used to verify the exactly-once guard
/// (the regular spy ignores the handler, which would not exercise the multiple-call crash path).
@interface PWNCDPCompletingSpy : NSObject <UNUserNotificationCenterDelegate>

@property (nonatomic) NSUInteger willPresentCount;
@property (nonatomic) NSUInteger didReceiveResponseCount;

@end

@implementation PWNCDPCompletingSpy

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    _willPresentCount++;
    completionHandler(UNNotificationPresentationOptionAlert);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
    _didReceiveResponseCount++;
    completionHandler();
}

@end

/// Delegate that stashes the completion handler and invokes it later, imitating a third-party SDK
/// that does async work before deciding presentation options — exercises the async-completion path.
@interface PWNCDPAsyncCompletingSpy : NSObject <UNUserNotificationCenterDelegate>

@property (nonatomic, copy) void (^stashedWillPresentHandler)(UNNotificationPresentationOptions);
@property (nonatomic, copy) void (^stashedDidReceiveHandler)(void);

@end

@implementation PWNCDPAsyncCompletingSpy

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    _stashedWillPresentHandler = completionHandler;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
    _stashedDidReceiveHandler = completionHandler;
}

@end

@interface PWNotificationCenterDelegateProxyTest : XCTestCase

@property (nonatomic, strong) id mockManager;
@property (nonatomic, strong) PWNotificationCenterDelegateProxy *proxy;
@property (nonatomic, weak) id originalCenterDelegate;
@property (nonatomic, strong) NSMutableArray *helperMocks;

@end

@implementation PWNotificationCenterDelegateProxyTest

- (void)setUp {
    [super setUp];
    [PWNotificationCenterDelegateProxy setCompletionFallbackDelayForTesting:0.05];
    _originalCenterDelegate = [UNUserNotificationCenter currentNotificationCenter].delegate;
    _mockManager = OCMClassMock([PWPushNotificationsManager class]);
    _proxy = [[PWNotificationCenterDelegateProxy alloc] initWithNotificationManager:_mockManager];
    _helperMocks = [NSMutableArray array];
}

- (void)tearDown {
    [UNUserNotificationCenter currentNotificationCenter].delegate = _originalCenterDelegate;
    for (id mock in _helperMocks) {
        [mock stopMocking];
    }
    _helperMocks = nil;
    [_mockManager stopMocking];
    [super tearDown];
}

#pragma mark - Helpers

- (id)mockRemoteNotificationWithUserInfo:(NSDictionary *)userInfo {
    id mockTrigger = OCMClassMock([UNPushNotificationTrigger class]);
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.userInfo = userInfo;
    id mockRequest = OCMClassMock([UNNotificationRequest class]);
    OCMStub([mockRequest trigger]).andReturn(mockTrigger);
    OCMStub([mockRequest content]).andReturn(content);
    OCMStub([mockRequest identifier]).andReturn(@"test-id");
    id mockNotification = OCMClassMock([UNNotification class]);
    OCMStub([mockNotification request]).andReturn(mockRequest);
    [_helperMocks addObjectsFromArray:@[mockTrigger, mockRequest, mockNotification]];
    return mockNotification;
}

- (id)mockResponseForNotification:(id)notification actionIdentifier:(NSString *)actionIdentifier {
    id mockResponse = OCMClassMock([UNNotificationResponse class]);
    OCMStub([mockResponse notification]).andReturn(notification);
    OCMStub([mockResponse actionIdentifier]).andReturn(actionIdentifier);
    [_helperMocks addObject:mockResponse];
    return mockResponse;
}

#pragma mark - init

/// Verifies that init creates a defaultNotificationCenterDelegate of the expected SDK type.
- (void)testInit_createsDefaultNotificationCenterDelegate {
    XCTAssertNotNil(_proxy.defaultNotificationCenterDelegate);
    XCTAssertTrue([_proxy.defaultNotificationCenterDelegate isKindOfClass:[PWUserNotificationCenterDelegate class]]);
}

#pragma mark - willPresentNotification routing

/// Verifies that a fresh Pushwoosh push (pw_msg present, no pw_push flag) IS forwarded to client delegates (first delivery).
- (void)testWillPresent_pushwooshFirstDelivery_forwardsToClientDelegate {
    PWNCDPClientSpy *spy = [PWNCDPClientSpy new];
    [_proxy addNotificationCenterDelegate:spy];

    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hi"}, @"pw_msg": @"1"};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
           willPresentNotification:notification
             withCompletionHandler:^(UNNotificationPresentationOptions options) {}];

    XCTAssertEqual(spy.willPresentCount, 1u);
}

/// Verifies that a re-presented Pushwoosh push (pw_push flag set) is NOT forwarded to client delegates (avoids duplicate delivery).
- (void)testWillPresent_pwPushFlagged_doesNotForwardToClient {
    PWNCDPClientSpy *spy = [PWNCDPClientSpy new];
    [_proxy addNotificationCenterDelegate:spy];

    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hi"}, @"pw_msg": @"1", @"pw_push": @YES};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
           willPresentNotification:notification
             withCompletionHandler:^(UNNotificationPresentationOptions options) {}];

    XCTAssertEqual(spy.willPresentCount, 0u, @"re-presented Pushwoosh push must not double-deliver to client delegates");
}

/// Verifies that a non-Pushwoosh push is still forwarded to client delegates (third-party push handling).
- (void)testWillPresent_nonPushwoosh_forwardsToClient {
    PWNCDPClientSpy *spy = [PWNCDPClientSpy new];
    [_proxy addNotificationCenterDelegate:spy];

    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hi from another sdk"}};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
           willPresentNotification:notification
             withCompletionHandler:^(UNNotificationPresentationOptions options) {}];

    XCTAssertEqual(spy.willPresentCount, 1u);
}

/// Verifies that multiple client delegates each receive the willPresent callback.
- (void)testWillPresent_multipleDelegates_allReceiveCallback {
    PWNCDPClientSpy *spyA = [PWNCDPClientSpy new];
    PWNCDPClientSpy *spyB = [PWNCDPClientSpy new];
    [_proxy addNotificationCenterDelegate:spyA];
    [_proxy addNotificationCenterDelegate:spyB];

    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hi"}};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
           willPresentNotification:notification
             withCompletionHandler:^(UNNotificationPresentationOptions options) {}];

    XCTAssertEqual(spyA.willPresentCount, 1u);
    XCTAssertEqual(spyB.willPresentCount, 1u);
}

#pragma mark - didReceiveNotificationResponse routing

/// Verifies that a Pushwoosh push response is forwarded to client delegates (response routing is always shared).
- (void)testDidReceive_pushwooshPush_forwardsToClient {
    PWNCDPClientSpy *spy = [PWNCDPClientSpy new];
    [_proxy addNotificationCenterDelegate:spy];

    NSDictionary *userInfo = @{@"aps": @{}, @"pw_msg": @"1"};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];
    id response = [self mockResponseForNotification:notification actionIdentifier:UNNotificationDefaultActionIdentifier];

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
    didReceiveNotificationResponse:response
             withCompletionHandler:^{}];

    XCTAssertEqual(spy.didReceiveResponseCount, 1u);
}

/// Verifies that a non-Pushwoosh response is still forwarded to client delegates.
- (void)testDidReceive_nonPushwooshPush_forwardsToClient {
    PWNCDPClientSpy *spy = [PWNCDPClientSpy new];
    [_proxy addNotificationCenterDelegate:spy];

    NSDictionary *userInfo = @{@"aps": @{}};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];
    id response = [self mockResponseForNotification:notification actionIdentifier:UNNotificationDefaultActionIdentifier];

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
    didReceiveNotificationResponse:response
             withCompletionHandler:^{}];

    XCTAssertEqual(spy.didReceiveResponseCount, 1u);
}

#pragma mark - openSettingsForNotification

/// Verifies that openSettingsForNotification is forwarded to client delegates that respond to the selector.
- (void)testOpenSettings_forwardsToClient {
    PWNCDPClientSpy *spy = [PWNCDPClientSpy new];
    [_proxy addNotificationCenterDelegate:spy];

    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{}}];

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
      openSettingsForNotification:notification];

    XCTAssertEqual(spy.openSettingsCount, 1u);
}

/// Verifies that openSettings is forwarded to a delegate that ONLY implements openSettings (respondsToSelector filtering).
- (void)testOpenSettings_partialResponder_stillReceivesCallback {
    PWNCDPOpenSettingsOnlyDelegate *partial = [PWNCDPOpenSettingsOnlyDelegate new];
    [_proxy addNotificationCenterDelegate:partial];

    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{}}];

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
      openSettingsForNotification:notification];

    XCTAssertEqual(partial.openSettingsCount, 1u);
}

/// Verifies that a delegate not implementing openSettings is safely skipped without crash.
- (void)testOpenSettings_nonRespondingDelegate_doesNotCrash {
    [_proxy addNotificationCenterDelegate:(id<UNUserNotificationCenterDelegate>)[NSObject new]];

    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{}}];

    XCTAssertNoThrow([_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
                       openSettingsForNotification:notification]);
}

#pragma mark - addNotificationCenterDelegate

/// Verifies that addNotificationCenterDelegate accumulates delegates rather than replacing the previous one.
- (void)testAddDelegate_accumulatesRatherThanReplaces {
    PWNCDPClientSpy *spyA = [PWNCDPClientSpy new];
    PWNCDPClientSpy *spyB = [PWNCDPClientSpy new];
    [_proxy addNotificationCenterDelegate:spyA];
    [_proxy addNotificationCenterDelegate:spyB];

    NSDictionary *userInfo = @{@"aps": @{}};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];
    id response = [self mockResponseForNotification:notification actionIdentifier:UNNotificationDefaultActionIdentifier];

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
    didReceiveNotificationResponse:response
             withCompletionHandler:^{}];

    XCTAssertEqual(spyA.didReceiveResponseCount, 1u);
    XCTAssertEqual(spyB.didReceiveResponseCount, 1u);
}

#pragma mark - exactly-once completion handler (crash fix)

/// Verifies the willPresent system completion handler runs exactly once even when several delegates
/// each call their handler — the guard that prevents the iOS multiple-call crash.
- (void)testWillPresent_multipleDelegatesCallHandler_systemHandlerCalledOnce {
    [_proxy addNotificationCenterDelegate:[PWNCDPCompletingSpy new]];
    [_proxy addNotificationCenterDelegate:[PWNCDPCompletingSpy new]];

    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{@"alert": @"hi"}}];
    __block NSUInteger systemHandlerCalls = 0;
    __block UNNotificationPresentationOptions capturedOptions = UNNotificationPresentationOptionNone;

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
           willPresentNotification:notification
             withCompletionHandler:^(UNNotificationPresentationOptions options) { systemHandlerCalls++; capturedOptions = options; }];

    XCTAssertEqual(systemHandlerCalls, 1u, @"system completion handler must fire exactly once");
    XCTAssertEqual(capturedOptions, UNNotificationPresentationOptionAlert, @"first-caller options must be preserved, not overwritten by the fallback");
}

/// Verifies the didReceiveResponse system completion handler runs exactly once with multiple delegates.
- (void)testDidReceive_multipleDelegatesCallHandler_systemHandlerCalledOnce {
    [_proxy addNotificationCenterDelegate:[PWNCDPCompletingSpy new]];
    [_proxy addNotificationCenterDelegate:[PWNCDPCompletingSpy new]];

    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{}}];
    id response = [self mockResponseForNotification:notification actionIdentifier:UNNotificationDefaultActionIdentifier];
    __block NSUInteger systemHandlerCalls = 0;

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
    didReceiveNotificationResponse:response
             withCompletionHandler:^{ systemHandlerCalls++; }];

    XCTAssertEqual(systemHandlerCalls, 1u, @"system completion handler must fire exactly once");
}

/// Verifies an async delegate's deferred willPresent completion is not pre-empted: the fallback must
/// NOT fire while a forwarded delegate still owns the handler, so the delegate's options survive.
- (void)testWillPresent_asyncDelegate_optionsPreservedNotSwallowedByFallback {
    PWNCDPAsyncCompletingSpy *async = [PWNCDPAsyncCompletingSpy new];
    [_proxy addNotificationCenterDelegate:async];

    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{@"alert": @"hi"}}];
    __block NSUInteger systemHandlerCalls = 0;
    __block UNNotificationPresentationOptions capturedOptions = UNNotificationPresentationOptionNone;

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
           willPresentNotification:notification
             withCompletionHandler:^(UNNotificationPresentationOptions options) { systemHandlerCalls++; capturedOptions = options; }];

    XCTAssertEqual(systemHandlerCalls, 0u, @"fallback must not fire while a forwarded delegate still owns the handler");

    async.stashedWillPresentHandler(UNNotificationPresentationOptionAlert);

    XCTAssertEqual(systemHandlerCalls, 1u, @"system handler fires once, when the async delegate completes");
    XCTAssertEqual(capturedOptions, UNNotificationPresentationOptionAlert, @"the async delegate's options must survive, not be replaced by the fallback's None");
}

/// Verifies an async delegate's deferred didReceiveResponse completion is not pre-empted by the fallback.
- (void)testDidReceive_asyncDelegate_completionNotPreEmptedByFallback {
    PWNCDPAsyncCompletingSpy *async = [PWNCDPAsyncCompletingSpy new];
    [_proxy addNotificationCenterDelegate:async];

    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{}}];
    id response = [self mockResponseForNotification:notification actionIdentifier:UNNotificationDefaultActionIdentifier];
    __block NSUInteger systemHandlerCalls = 0;

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
    didReceiveNotificationResponse:response
             withCompletionHandler:^{ systemHandlerCalls++; }];

    XCTAssertEqual(systemHandlerCalls, 0u, @"fallback must not fire while a forwarded delegate still owns the handler");

    async.stashedDidReceiveHandler();

    XCTAssertEqual(systemHandlerCalls, 1u, @"system handler fires once, when the async delegate completes");
}

/// Verifies the deferred fallback still fires the willPresent system handler when a forwarded delegate
/// received the callback but never completed it (a misbehaving silent third-party SDK).
- (void)testWillPresent_silentDelegate_fallbackFiresAfterDelay {
    PWNCDPClientSpy *silent = [PWNCDPClientSpy new]; // responds to willPresent but never calls the handler
    [_proxy addNotificationCenterDelegate:silent];

    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{@"alert": @"hi"}}];
    XCTestExpectation *exp = [self expectationWithDescription:@"willPresent fallback fires"];
    __block NSUInteger systemHandlerCalls = 0;

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
           willPresentNotification:notification
             withCompletionHandler:^(UNNotificationPresentationOptions options) { systemHandlerCalls++; [exp fulfill]; }];

    XCTAssertEqual(systemHandlerCalls, 0u, @"handler must not fire synchronously while a forwarded delegate may still complete");

    [self waitForExpectations:@[exp] timeout:1.0];
    XCTAssertEqual(systemHandlerCalls, 1u, @"deferred fallback must fire the handler once after the delay");
}

/// Verifies the deferred fallback still fires the didReceive system handler when a forwarded delegate
/// received the callback but never completed it.
- (void)testDidReceive_silentDelegate_fallbackFiresAfterDelay {
    PWNCDPClientSpy *silent = [PWNCDPClientSpy new];
    [_proxy addNotificationCenterDelegate:silent];

    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{}}];
    id response = [self mockResponseForNotification:notification actionIdentifier:UNNotificationDefaultActionIdentifier];
    XCTestExpectation *exp = [self expectationWithDescription:@"didReceive fallback fires"];
    __block NSUInteger systemHandlerCalls = 0;

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
    didReceiveNotificationResponse:response
             withCompletionHandler:^{ systemHandlerCalls++; [exp fulfill]; }];

    XCTAssertEqual(systemHandlerCalls, 0u, @"handler must not fire synchronously while a forwarded delegate may still complete");

    [self waitForExpectations:@[exp] timeout:1.0];
    XCTAssertEqual(systemHandlerCalls, 1u, @"deferred fallback must fire the handler once after the delay");
}

#pragma mark - pre-existing delegate capture

/// Verifies a delegate installed before Pushwoosh is preserved (keeps receiving callbacks) instead of
/// being silently orphaned when the proxy takes over as the UNUserNotificationCenter delegate.
- (void)testPreserveExistingDelegate_keepsItReceivingCallbacks {
    PWNCDPClientSpy *preExisting = [PWNCDPClientSpy new];
    [_proxy preserveExistingDelegate:preExisting];

    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{}}];
    id response = [self mockResponseForNotification:notification actionIdentifier:UNNotificationDefaultActionIdentifier];

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
           willPresentNotification:notification
             withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
      didReceiveNotificationResponse:response
               withCompletionHandler:^{}];

    XCTAssertEqual(preExisting.willPresentCount, 1u, @"a preserved delegate must receive willPresent callbacks");
    XCTAssertEqual(preExisting.didReceiveResponseCount, 1u, @"a delegate installed before Pushwoosh must be preserved and keep receiving callbacks");
}

/// Verifies the preserved pre-Pushwoosh delegate is held WEAKLY: once the host releases it the proxy
/// does not keep it alive, so Pushwoosh never silently extends another delegate's lifetime.
- (void)testPreserveExistingDelegate_heldWeakly_notRetainedByProxy {
    __weak PWNCDPClientSpy *weakPreExisting;
    @autoreleasepool {
        PWNCDPClientSpy *preExisting = [PWNCDPClientSpy new];
        weakPreExisting = preExisting;
        [_proxy preserveExistingDelegate:preExisting];
        XCTAssertNotNil(weakPreExisting, @"sanity: delegate is alive while the host holds it");
    }
    XCTAssertNil(weakPreExisting, @"preserved delegate must be held weakly, not retained by the proxy");
}

/// Verifies the system handler still fires exactly once for a non-Pushwoosh push with no registered
/// delegates — the fallback that prevents a hung notification when nothing else calls the handler.
- (void)testWillPresent_noDelegatesNonPushwoosh_stillCallsHandlerOnce {
    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{@"alert": @"hi"}}];
    __block NSUInteger systemHandlerCalls = 0;

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
           willPresentNotification:notification
             withCompletionHandler:^(UNNotificationPresentationOptions options) { systemHandlerCalls++; }];

    XCTAssertEqual(systemHandlerCalls, 1u, @"handler must fire once via fallback even with no delegates");
}

/// Verifies the didReceiveResponse system handler still fires exactly once for a non-Pushwoosh response
/// with no registered delegates — symmetric fallback to willPresent (prevents a hung response handler).
- (void)testDidReceive_noDelegatesNonPushwoosh_stillCallsHandlerOnce {
    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{}}];
    id response = [self mockResponseForNotification:notification actionIdentifier:UNNotificationDefaultActionIdentifier];
    __block NSUInteger systemHandlerCalls = 0;

    [_proxy userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
    didReceiveNotificationResponse:response
             withCompletionHandler:^{ systemHandlerCalls++; }];

    XCTAssertEqual(systemHandlerCalls, 1u, @"response handler must fire once via fallback even with no delegates");
}

@end

#endif
