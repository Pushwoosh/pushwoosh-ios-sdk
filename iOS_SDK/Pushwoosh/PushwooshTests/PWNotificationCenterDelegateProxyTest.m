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

@interface PWNotificationCenterDelegateProxyTest : XCTestCase

@property (nonatomic, strong) id mockManager;
@property (nonatomic, strong) PWNotificationCenterDelegateProxy *proxy;
@property (nonatomic, weak) id originalCenterDelegate;
@property (nonatomic, strong) NSMutableArray *helperMocks;

@end

@implementation PWNotificationCenterDelegateProxyTest

- (void)setUp {
    [super setUp];
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

@end

#endif
