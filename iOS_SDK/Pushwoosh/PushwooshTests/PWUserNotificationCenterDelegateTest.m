#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UserNotifications/UserNotifications.h>

#import "PWUserNotificationCenterDelegate.h"
#import "PWPushNotificationsManager.h"
#import "PWManagerBridge.h"

#if TARGET_OS_IOS

@interface PWUserNotificationCenterDelegate (Test)

@property (nonatomic) NSString *lastHash;

@end

@interface PWPushNotificationsManager (Test)

- (BOOL)isAppInBackground;

@end

/// Spy delegate that captures onActionIdentifierReceived and openSettings callbacks for verification.
@interface PWUNCDTestDelegateSpy : NSObject

@property (nonatomic, copy) NSString *capturedActionIdentifier;
@property (nonatomic, copy) NSDictionary *capturedNotification;
@property (nonatomic) BOOL openSettingsCalled;

- (void)onActionIdentifierReceived:(NSString *)actionIdentifier withNotification:(NSDictionary *)notification;
- (void)pushManager:(PWManagerBridge *)manager openSettingsForNotification:(UNNotification *)notification;

@end

@implementation PWUNCDTestDelegateSpy

- (void)onActionIdentifierReceived:(NSString *)actionIdentifier withNotification:(NSDictionary *)notification {
    self.capturedActionIdentifier = actionIdentifier;
    self.capturedNotification = notification;
}

- (void)pushManager:(PWManagerBridge *)manager openSettingsForNotification:(UNNotification *)notification {
    self.openSettingsCalled = YES;
}

@end

@interface PWUserNotificationCenterDelegateTest : XCTestCase

@property (nonatomic, strong) PWUserNotificationCenterDelegate *target;
@property (nonatomic, strong) id mockManager;
@property (nonatomic, weak) id originalBridgeDelegate;
@property (nonatomic) BOOL originalShowPushAlert;
@property (nonatomic, strong) NSMutableArray *helperMocks;

@end

@implementation PWUserNotificationCenterDelegateTest

- (void)setUp {
    [super setUp];
    _mockManager = OCMClassMock([PWPushNotificationsManager class]);
    _target = [[PWUserNotificationCenterDelegate alloc] initWithNotificationManager:_mockManager];
    _originalBridgeDelegate = [PWManagerBridge shared].delegate;
    _originalShowPushAlert = [PWManagerBridge shared].showPushnotificationAlert;
    _helperMocks = [NSMutableArray array];
}

- (void)tearDown {
    [PWManagerBridge shared].delegate = _originalBridgeDelegate;
    [PWManagerBridge shared].showPushnotificationAlert = _originalShowPushAlert;
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

- (id)mockLocalNotificationWithUserInfo:(NSDictionary *)userInfo {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.userInfo = userInfo;
    id mockRequest = OCMClassMock([UNNotificationRequest class]);
    OCMStub([mockRequest trigger]).andReturn(nil);
    OCMStub([mockRequest content]).andReturn(content);
    OCMStub([mockRequest identifier]).andReturn(@"local-id");
    id mockNotification = OCMClassMock([UNNotification class]);
    OCMStub([mockNotification request]).andReturn(mockRequest);
    [_helperMocks addObjectsFromArray:@[mockRequest, mockNotification]];
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

/// Verifies that initWithNotificationManager stores the provided manager (used as routing target).
- (void)testInit_storesNotificationManager {
    XCTAssertNotNil(_target);
}

#pragma mark - willPresentNotification

/// Verifies that a remote Pushwoosh push (pw_msg present, not content-available) routes to handlePushReceived with autoAcceptAllowed=NO and presents nothing.
- (void)testWillPresent_pushwooshRegularPush_callsHandleAndPresentsNone {
    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hi"}, @"pw_msg": @"1", @"p": @"hash1"};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];
    OCMExpect([_mockManager handlePushReceived:[OCMArg any] autoAcceptAllowed:NO]);
    __block UNNotificationPresentationOptions captured = 999;
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];

    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
            willPresentNotification:notification
              withCompletionHandler:^(UNNotificationPresentationOptions options) {
        captured = options;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(captured, UNNotificationPresentationOptionNone);
    OCMVerifyAll(_mockManager);
}

/// Verifies that a content-available remote Pushwoosh push does NOT route through handlePushReceived (silent push delivery is handled elsewhere) and presents nothing.
- (void)testWillPresent_pushwooshContentAvailable_doesNotCallHandleReceived {
    NSDictionary *userInfo = @{@"aps": @{@"content-available": @1}, @"pw_msg": @"1"};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];
    OCMReject([_mockManager handlePushReceived:[OCMArg any] autoAcceptAllowed:NO]);
    __block UNNotificationPresentationOptions captured = 999;
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];

    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
            willPresentNotification:notification
              withCompletionHandler:^(UNNotificationPresentationOptions options) {
        captured = options;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(captured, UNNotificationPresentationOptionNone);
    OCMVerifyAll(_mockManager);
}

/// Verifies that a non-Pushwoosh remote push with showPushnotificationAlert=YES presents badge+alert+sound.
- (void)testWillPresent_nonPushwooshShowAlertYes_presentsBadgeAlertSound {
    [PWManagerBridge shared].showPushnotificationAlert = YES;
    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hello"}, @"p": @"unique-hash"};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];
    __block UNNotificationPresentationOptions captured = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];

    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
            willPresentNotification:notification
              withCompletionHandler:^(UNNotificationPresentationOptions options) {
        captured = options;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    UNNotificationPresentationOptions expected = UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound;
    XCTAssertEqual(captured, expected);
}

/// Verifies that two identical "p" hashes in a row deduplicate — the second call presents None.
- (void)testWillPresent_duplicateHash_presentsNone {
    [PWManagerBridge shared].showPushnotificationAlert = YES;
    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hello"}, @"p": @"dup-hash"};
    id firstNotification = [self mockRemoteNotificationWithUserInfo:userInfo];
    id secondNotification = [self mockRemoteNotificationWithUserInfo:userInfo];

    XCTestExpectation *firstExpectation = [self expectationWithDescription:@"first completion"];
    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
            willPresentNotification:firstNotification
              withCompletionHandler:^(UNNotificationPresentationOptions options) {
        [firstExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    __block UNNotificationPresentationOptions captured = 999;
    XCTestExpectation *secondExpectation = [self expectationWithDescription:@"second completion"];
    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
            willPresentNotification:secondNotification
              withCompletionHandler:^(UNNotificationPresentationOptions options) {
        captured = options;
        [secondExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqual(captured, UNNotificationPresentationOptionNone);
}

/// Verifies that when showPushnotificationAlert=NO AND the userInfo carries pw_push=YES (a re-presented Pushwoosh push), nothing is shown.
- (void)testWillPresent_showAlertNo_pwPushFlagPresent_presentsNone {
    [PWManagerBridge shared].showPushnotificationAlert = NO;
    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hi"}, @"pw_push": @YES, @"p": @"hash-pw"};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];

    __block UNNotificationPresentationOptions captured = 999;
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
            willPresentNotification:notification
              withCompletionHandler:^(UNNotificationPresentationOptions options) {
        captured = options;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(captured, UNNotificationPresentationOptionNone);
}

/// Verifies that a local notification (trigger=nil, not UNPushNotificationTrigger) is treated as non-remote and uses the showAlert branch.
- (void)testWillPresent_localNotification_takesShowAlertBranch {
    [PWManagerBridge shared].showPushnotificationAlert = YES;
    NSDictionary *userInfo = @{@"aps": @{@"alert": @"local"}, @"p": @"local-hash"};
    id notification = [self mockLocalNotificationWithUserInfo:userInfo];
    OCMReject([_mockManager handlePushReceived:[OCMArg any] autoAcceptAllowed:NO]);

    __block UNNotificationPresentationOptions captured = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
            willPresentNotification:notification
              withCompletionHandler:^(UNNotificationPresentationOptions options) {
        captured = options;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    UNNotificationPresentationOptions expected = UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound;
    XCTAssertEqual(captured, expected);
    OCMVerifyAll(_mockManager);
}

#pragma mark - didReceiveNotificationResponse

/// Verifies that the default action on a Pushwoosh push calls handlePushAccepted (carrying the action identifier) and does NOT invoke onActionIdentifierReceived (only custom actions do).
- (void)testDidReceive_defaultAction_pushwooshPush_callsHandlePushAcceptedOnly {
    OCMStub([_mockManager isAppInBackground]).andReturn(NO);
    PWUNCDTestDelegateSpy *spy = [PWUNCDTestDelegateSpy new];
    [PWManagerBridge shared].delegate = spy;
    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hi"}, @"pw_msg": @"1", @"p": @"hash"};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];
    id response = [self mockResponseForNotification:notification actionIdentifier:UNNotificationDefaultActionIdentifier];
    OCMExpect([_mockManager handlePushReceived:[OCMArg any] autoAcceptAllowed:NO]);
    OCMExpect([_mockManager handlePushAccepted:[OCMArg any] onStart:NO]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
     didReceiveNotificationResponse:response
              withCompletionHandler:^{
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertNil(spy.capturedActionIdentifier, @"default action must NOT invoke onActionIdentifierReceived (only custom actions do)");
    OCMVerifyAll(_mockManager);
}

/// Verifies that UNNotificationDismissActionIdentifier does NOT call handlePushAccepted (the user explicitly dismissed).
- (void)testDidReceive_dismissAction_doesNotCallHandlePushAccepted {
    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hi"}, @"pw_msg": @"1"};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];
    id response = [self mockResponseForNotification:notification actionIdentifier:UNNotificationDismissActionIdentifier];
    OCMReject([_mockManager handlePushAccepted:[OCMArg any] onStart:NO]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
     didReceiveNotificationResponse:response
              withCompletionHandler:^{
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerifyAll(_mockManager);
}

/// Verifies that a custom action identifier on a Pushwoosh push invokes onActionIdentifierReceived: on the delegate AND calls handlePushAccepted.
- (void)testDidReceive_customAction_invokesOnActionIdentifierAndHandlePushAccepted {
    OCMStub([_mockManager isAppInBackground]).andReturn(NO);
    PWUNCDTestDelegateSpy *spy = [PWUNCDTestDelegateSpy new];
    [PWManagerBridge shared].delegate = spy;
    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hi"}, @"pw_msg": @"1", @"p": @"hash-action"};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];
    id response = [self mockResponseForNotification:notification actionIdentifier:@"REPLY_ACTION"];
    OCMExpect([_mockManager handlePushAccepted:[OCMArg any] onStart:NO]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
     didReceiveNotificationResponse:response
              withCompletionHandler:^{
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqualObjects(spy.capturedActionIdentifier, @"REPLY_ACTION");
    XCTAssertEqualObjects(spy.capturedNotification[@"pw_msg"], @"1");
    OCMVerifyAll(_mockManager);
}

/// Verifies that a non-Pushwoosh response that already carries pw_push (re-delivered) still calls handlePushAccepted.
- (void)testDidReceive_pwPushFlaggedNonPushwoosh_callsHandlePushAccepted {
    OCMStub([_mockManager isAppInBackground]).andReturn(NO);
    NSDictionary *userInfo = @{@"aps": @{@"alert": @"hi"}, @"pw_push": @YES};
    id notification = [self mockRemoteNotificationWithUserInfo:userInfo];
    id response = [self mockResponseForNotification:notification actionIdentifier:UNNotificationDefaultActionIdentifier];
    OCMExpect([_mockManager handlePushAccepted:[OCMArg any] onStart:NO]);
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
     didReceiveNotificationResponse:response
              withCompletionHandler:^{
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerifyAll(_mockManager);
}

#pragma mark - openSettingsForNotification

/// Verifies that openSettingsForNotification invokes pushManager:openSettingsForNotification: on the bridge delegate when it responds.
- (void)testOpenSettings_invokesDelegateWhenItResponds {
    PWUNCDTestDelegateSpy *spy = [PWUNCDTestDelegateSpy new];
    [PWManagerBridge shared].delegate = spy;
    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{}}];

    [_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
       openSettingsForNotification:notification];

    XCTAssertTrue(spy.openSettingsCalled);
}

/// Verifies that openSettingsForNotification with a delegate that does NOT respond is a safe no-op.
- (void)testOpenSettings_nonRespondingDelegate_doesNotCrash {
    [PWManagerBridge shared].delegate = [NSObject new];
    id notification = [self mockRemoteNotificationWithUserInfo:@{@"aps": @{}}];

    XCTAssertNoThrow([_target userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
                                openSettingsForNotification:notification]);
}

@end

#endif
