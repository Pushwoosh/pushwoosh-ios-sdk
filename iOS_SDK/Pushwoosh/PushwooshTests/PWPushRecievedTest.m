#import "PWRequestManagerMock.h"
#import "PWNetworkModule.h"
#import "PWTestUtils.h"
#import "PushNotificationManager.h"
#import "PWPreferences.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"
#import "PWNotificationCategoryBuilder.h"
#import "PWPushNotificationDelegateMock.h"
#import "PWPushNotificationCustomDelegateMock.h"
#import "PWRegisterDeviceRequest.h"
#import "PWUnregisterDeviceRequest.h"
#import "PWUtils.h"
#import "PWPushStatRequest.h"
#import "PushwooshFramework.h"
#import "PWBundleMock.h"
#import "PWConfig.h"
#import <OCMock/OCMock.h>

#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import <XCTest/XCTest.h>

@interface PWPushRecievedTest : XCTestCase

@property PushNotificationManager *pushManager;
@property (nonatomic, strong) PWRequestManager *originalRequestManager;
@property (nonatomic, strong) PWRequestManagerMock *mockRequestManager;
@property (nonatomic, strong) PWPushNotificationDelegateMock *mockNotificationDelegate;
@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;
@property (nonatomic, strong) PWNotificationManagerCompat *mockNotificationManager;
@property (nonatomic, strong) Class originalCategoryBuilder;
@property (nonatomic, strong) id mockUIApplication;

@end

@implementation PWPushRecievedTest

- (void)setUp {
    [super setUp];

    self.mockUIApplication = OCMClassMock([UIApplication class]);
    OCMStub([self.mockUIApplication sharedApplication]).andReturn(self.mockUIApplication);
    OCMStub([self.mockUIApplication applicationState]).andReturn(UIApplicationStateActive);

    self.originalRequestManager = [PWNetworkModule module].requestManager;
    self.mockRequestManager = [PWRequestManagerMock new];
    [PWNetworkModule module].requestManager = self.mockRequestManager;

    self.mockNotificationManager = mock([PWNotificationManagerCompat class]);
    self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
    [PWPlatformModule module].notificationManagerCompat = self.mockNotificationManager;

    [givenVoid([self.mockNotificationManager getRemoteNotificationStatusWithCompletion:anything()]) willDo:^id (NSInvocation *invocation) {
        NSArray *args = [invocation mkt_arguments];
        void (^completion)(NSDictionary*) = args[0];
        completion(nil);
        return nil;
    }];

    self.originalCategoryBuilder = [PWPlatformModule module].NotificationCategoryBuilder;
    [PWPlatformModule module].NotificationCategoryBuilder = [PWNotificationCategoryBuilder class];

    self.mockNotificationDelegate = [PWPushNotificationDelegateMock new];

    [PushNotificationManager initializeWithAppCode:@"4FC89B6D14A655-46488481" appName:@"UnitTest"];
    self.pushManager = [PushNotificationManager pushManager];
    [PushNotificationManager pushManager].delegate = self.mockNotificationDelegate;
}

- (void)tearDown {
    [self.mockUIApplication stopMocking];
    self.mockUIApplication = nil;

    [PWNetworkModule module].requestManager = self.originalRequestManager;
    self.pushManager = nil;
    self.mockNotificationDelegate = nil;
    [PWPlatformModule module].notificationManagerCompat = self.originalNotificationManager;
    [PWPlatformModule module].NotificationCategoryBuilder = self.originalCategoryBuilder;
    [PWTestUtils tearDown];

    [super tearDown];
}

/// Verifies that handlePushReceived returns NO when userInfo is not an NSDictionary.
- (void)testHandlePushReceivedNotNSDictinary {
    NSArray *userInfo = @[@"1", @"2", @"3"];

    BOOL methodResult = [self.pushManager handlePushReceived:(NSDictionary *)userInfo];

    XCTAssertFalse(methodResult);
}

/// Verifies that handlePushReceived returns NO when userInfo has no "aps" key.
- (void)testHandlePushReceivedApsDictionary {
    NSDictionary *userInfo = @{ @"!aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3" }, @"p" : @"42"};

    BOOL methodResult = [self.pushManager handlePushReceived:userInfo];

    XCTAssertFalse(methodResult);
}

/// Verifies that handlePushReceived sends a PWPushStatRequest carrying the hash from the userInfo "p" key when alerts are disabled.
- (void)testHandlePushReceivedHash {
    [PushNotificationManager pushManager].showPushnotificationAlert = NO;

    id mockPWConfigPartial = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfigPartial sendPushStatIfAlertsDisabled]).andReturn(YES);
    XCTestExpectation *requestExpectation = [self expectationWithDescription:@"pushStat sent"];
    NSDictionary *userInfo = @{ @"aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3" }, @"p" : @"42", @"pw_msg" : @"1"};
    __block PWRequest *pushStatRequest = nil;

    self.mockRequestManager.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWPushStatRequest class]]) {
            pushStatRequest = request;
            [requestExpectation fulfill];
        }
    };

    [self.pushManager handlePushReceived:userInfo];
    [self waitForExpectationsWithTimeout:3 handler:nil];

    XCTAssertEqualObjects(pushStatRequest.requestDictionary[@"hash"], userInfo[@"p"]);

    [mockPWConfigPartial stopMocking];
}

/// Verifies that handlePushReceived still sends a PWPushStatRequest when the userInfo has no "p" key, with a nil hash field.
- (void)testHandlePushReceivedNilHash {
    [PushNotificationManager pushManager].showPushnotificationAlert = NO;

    id mockPWConfigPartial = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfigPartial sendPushStatIfAlertsDisabled]).andReturn(YES);
    XCTestExpectation *requestExpectation = [self expectationWithDescription:@"pushStat sent"];
    NSDictionary *userInfo = @{ @"aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3"}, @"pw_msg" : @"1"};
    __block PWRequest *pushStatRequest = nil;
    __block BOOL requestSent = NO;

    self.mockRequestManager.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWPushStatRequest class]]) {
            pushStatRequest = request;
            requestSent = YES;
            [requestExpectation fulfill];
        }
    };

    [self.pushManager handlePushReceived:userInfo];
    [self waitForExpectationsWithTimeout:3 handler:nil];

    XCTAssertNil(pushStatRequest.requestDictionary[@"hash"]);
    XCTAssertTrue(requestSent);

    [mockPWConfigPartial stopMocking];
}

/// Verifies that handlePushReceived invokes the delegate's onPushReceived:withNotification:onStart: callback.
- (void)testHandlePushReceivedOnPushReceivedCalled {
    NSDictionary *userInfo = @{ @"aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3"}, @"pw_msg" : @"1"};

    BOOL methodResults = [self.pushManager handlePushReceived:userInfo];

    [verify(self.mockNotificationDelegate.mock) onPushReceived:self.pushManager withNotification:userInfo onStart:NO];
    XCTAssertTrue(methodResults);
}

/// Verifies that getApnPayload extracts the "aps" subdictionary from a push notification dictionary.
- (void)testGetApnPayload {
    NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"pw_msg" : @"1"};

    id methodResult = [self.pushManager getApnPayload:pushNotification];

    XCTAssertTrue([methodResult isKindOfClass:[NSDictionary class]]);
    XCTAssertEqualObjects(methodResult, pushNotification[@"aps"]);
}

/// Verifies that getCustomPushData returns the raw NSString value from the "u" key.
- (void)testGetApnPayloadGetCustomPushData {
    NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"u" : @"custom data", @"pw_msg" : @"1"};

    id methodResult = [self.pushManager getCustomPushData:pushNotification];

    XCTAssertTrue([methodResult isKindOfClass:[NSString class]]);
    XCTAssertEqualObjects(methodResult, pushNotification[@"u"]);
}

/// Verifies that getCustomPushData returns nil when the "u" key holds NSNull.
- (void)testGetApnPayloadGetCustomPushDataNull {
    NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"u" : [NSNull null], @"pw_msg" : @"1"};

    id methodResult = [self.pushManager getCustomPushData:pushNotification];

    XCTAssertNil(methodResult);
}

/// Verifies that getCustomPushDataAsNSDict returns nil when the "u" key is missing.
- (void)testGetApnPayloadNilCustomPushDataAsNSDict {
    NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"pw_msg" : @"1"};

    id methodResult = [self.pushManager getCustomPushDataAsNSDict:pushNotification];

    XCTAssertNil(methodResult);
}

/// Verifies that getCustomPushDataAsNSDict returns nil when the "u" key holds NSNull.
- (void)testGetApnPayloadNullCustomPushDataAsNSDict {
    NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"u" : [NSNull null], @"pw_msg" : @"1"};

    id methodResult = [self.pushManager getCustomPushDataAsNSDict:pushNotification];

    XCTAssertNil(methodResult);
}

/// Verifies that getCustomPushDataAsNSDict returns nil when "u" parses to a JSON array (not an object).
- (void)testGetApnPayloadArrayCustomPushDataAsNSDict {
    NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"u" : @"[1, \"b\"]", @"pw_msg" : @"1"};

    id methodResult = [self.pushManager getCustomPushDataAsNSDict:pushNotification];

    XCTAssertNil(methodResult);
}

/// Verifies that getCustomPushDataAsNSDict parses a JSON object from the "u" key into an NSDictionary.
- (void)testGetApnPayloadGetCustomPushDataAsNSDict {
    NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"u" : @"{\"r\":30, \"g\":144, \"b\":255}"};

    id methodResult = [self.pushManager getCustomPushDataAsNSDict:pushNotification];

    XCTAssertTrue([methodResult isKindOfClass:[NSDictionary class]]);
    XCTAssertEqualObjects(methodResult[@"r"], @30);
    XCTAssertEqualObjects(methodResult[@"g"], @144);
    XCTAssertEqualObjects(methodResult[@"b"], @255);
}

@end
