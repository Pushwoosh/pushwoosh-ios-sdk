#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PushwooshConfig.h"
#import "PWManagerBridge.h"
#import "PWPreferences.h"
#import "PWConfig.h"
#import "PWSdkStateProvider.h"
#import "PWServerCommunicationManager.h"
#import "PWDataManager.h"
#import "PWPushNotificationsManager.h"
#import "PWInAppManager.h"
#import "PWNetworkModule.h"
#import "PWRequestManager.h"

@interface PWSdkStateProvider (PushwooshConfigTest)

- (void)resetForTesting;
- (void)setReady;

@end

@interface PWServerCommunicationManager (PushwooshConfigTest)

- (BOOL)isServerCommunicationAllowed;
- (void)startServerCommunication;
- (void)stopServerCommunication;

@end

@interface PushwooshConfigTest : XCTestCase

@property (nonatomic, copy) NSString *originalAppCode;
@property (nonatomic, copy) NSString *originalApiToken;
@property (nonatomic, copy) NSString *originalLanguage;
@property (nonatomic, copy) NSString *originalAdvertisingId;
@property (nonatomic, strong) PWDataManager *originalDataManager;
@property (nonatomic, strong) PWPushNotificationsManager *originalPushNotificationManager;
@property (nonatomic, strong) PWInAppManager *originalInAppManager;
@property (nonatomic, weak) id originalDelegate;
@property (nonatomic, strong) NSMutableArray *networkMocks;

@end

@implementation PushwooshConfigTest

- (void)setUp {
    [super setUp];
    _originalAppCode = [[PWPreferences preferences].appCode copy];
    _originalApiToken = [[PWPreferences preferences].apiToken copy];
    _originalLanguage = [[PWPreferences preferences].language copy];
    _originalAdvertisingId = [[PWPreferences preferences].advertisingId copy];
    _originalDataManager = [PWManagerBridge shared].dataManager;
    _originalPushNotificationManager = [PWManagerBridge shared].pushNotificationManager;
    _originalInAppManager = [PWManagerBridge shared].inAppManager;
    _originalDelegate = [PWManagerBridge shared].delegate;

    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [[PWSdkStateProvider sharedInstance] setReady];
    _networkMocks = [NSMutableArray array];
}

/// Mocks PWNetworkModule so PushwooshConfig dispatches requests through a fake requestManager that the test can verify.
- (id)mockRequestManager {
    id reqManager = OCMClassMock([PWRequestManager class]);
    id netModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([netModule module]).andReturn(netModule);
    OCMStub([(PWNetworkModule *)netModule requestManager]).andReturn(reqManager);
    [_networkMocks addObjectsFromArray:@[netModule, reqManager]];
    return reqManager;
}

- (void)tearDown {
    for (id mock in _networkMocks) {
        [mock stopMocking];
    }
    _networkMocks = nil;
    [PWPreferences preferences].appCode = _originalAppCode;
    [PWPreferences preferences].apiToken = _originalApiToken;
    [PWPreferences preferences].language = _originalLanguage;
    [PWPreferences preferences].advertisingId = _originalAdvertisingId;
    [PWManagerBridge shared].dataManager = _originalDataManager;
    [PWManagerBridge shared].pushNotificationManager = _originalPushNotificationManager;
    [PWManagerBridge shared].inAppManager = _originalInAppManager;
    [PWManagerBridge shared].delegate = _originalDelegate;
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [super tearDown];
}

#pragma mark - configure

/// Verifies that configure returns the PushwooshConfig class itself so callers can chain .methodName().
- (void)testConfigure_returnsSelfClass {
    XCTAssertEqual([PushwooshConfig configure], [PushwooshConfig class]);
}

#pragma mark - setAppCode trim + dotted rejection

/// Verifies that setAppCode persists a trimmed (whitespace-stripped) value into PWPreferences.
- (void)testSetAppCode_persistsTrimmedValue {
    [PushwooshConfig setAppCode:@"  XXXXX-12345  "];

    XCTAssertEqualObjects([PWPreferences preferences].appCode, @"XXXXX-12345");
}

/// Verifies that setAppCode with whitespace-only value is ignored (does not overwrite existing appCode).
- (void)testSetAppCode_whitespaceOnly_isIgnored {
    [PWPreferences preferences].appCode = @"PRIOR-CODE";

    [PushwooshConfig setAppCode:@"   \n\t  "];

    XCTAssertEqualObjects([PWPreferences preferences].appCode, @"PRIOR-CODE");
}

/// Verifies that setAppCode rejects appCodes containing "." (deprecated dotted format from SDK-814).
- (void)testSetAppCode_dottedFormat_isRejected {
    [PWPreferences preferences].appCode = @"PRIOR-CODE";

    [PushwooshConfig setAppCode:@"XXXXX-12345.legacy"];

    XCTAssertEqualObjects([PWPreferences preferences].appCode, @"PRIOR-CODE");
}

#pragma mark - setApiToken trim

/// Verifies that setApiToken persists a trimmed value into PWPreferences.
- (void)testSetApiToken_persistsTrimmedValue {
    [PushwooshConfig setApiToken:@"  secret-token-123  "];

    XCTAssertEqualObjects([PWPreferences preferences].apiToken, @"secret-token-123");
}

/// Verifies that setApiToken with whitespace-only value is ignored.
- (void)testSetApiToken_whitespaceOnly_isIgnored {
    [PWPreferences preferences].apiToken = @"prior-token";

    [PushwooshConfig setApiToken:@"   "];

    XCTAssertEqualObjects([PWPreferences preferences].apiToken, @"prior-token");
}

/// Verifies that getApiToken reads from PWPreferences.
- (void)testGetApiToken_readsPreferences {
    [PWPreferences preferences].apiToken = @"read-back-token";

    XCTAssertEqualObjects([PushwooshConfig getApiToken], @"read-back-token");
}

#pragma mark - getAppCode / getApplicationCode

/// Verifies that getAppCode and getApplicationCode (alias) both return PWPreferences.appCode.
- (void)testGetAppCodeAndGetApplicationCode_returnSamePreferencesValue {
    [PWPreferences preferences].appCode = @"READBACK-CODE";

    XCTAssertEqualObjects([PushwooshConfig getAppCode], @"READBACK-CODE");
    XCTAssertEqualObjects([PushwooshConfig getApplicationCode], @"READBACK-CODE");
}

#pragma mark - setEmail trim

/// Verifies that setEmail trims input and forwards the trimmed value to PWManagerBridge.setEmailBlock.
- (void)testSetEmail_forwardsTrimmedValueToBridgeBlock {
    __block NSString *captured = nil;
    [PWManagerBridge shared].setEmailBlock = ^(NSString *email) {
        captured = email;
    };

    [PushwooshConfig setEmail:@"  user@example.com  "];

    XCTAssertEqualObjects(captured, @"user@example.com");
}

/// Verifies that setEmail with whitespace-only input does NOT invoke setEmailBlock.
- (void)testSetEmail_whitespaceOnly_doesNotInvokeBlock {
    __block BOOL invoked = NO;
    [PWManagerBridge shared].setEmailBlock = ^(NSString *email) {
        invoked = YES;
    };

    [PushwooshConfig setEmail:@"   "];

    XCTAssertFalse(invoked);
}

#pragma mark - setUserId trim

/// Verifies that setUserId forwards a trimmed value to the inAppManager.
- (void)testSetUserId_forwardsTrimmedValueToInAppManager {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    OCMExpect([mockInApp setUserId:@"user-123"]);
    [PWManagerBridge shared].inAppManager = mockInApp;

    [PushwooshConfig setUserId:@"  user-123  "];

    OCMVerifyAll(mockInApp);
}

/// Verifies that setUserId with whitespace-only input does NOT forward to inAppManager.
- (void)testSetUserId_whitespaceOnly_doesNotForward {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    OCMReject([mockInApp setUserId:[OCMArg any]]);
    [PWManagerBridge shared].inAppManager = mockInApp;

    [PushwooshConfig setUserId:@"\t\n  "];

    OCMVerifyAll(mockInApp);
}

#pragma mark - setTags forwarding

/// Verifies that setTags forwards the dictionary to PWManagerBridge.dataManager.
- (void)testSetTags_forwardsToBridgeDataManager {
    id mockDataManager = OCMClassMock([PWDataManager class]);
    NSDictionary *tags = @{@"k": @"v"};
    OCMExpect([mockDataManager setTags:tags]);
    [PWManagerBridge shared].dataManager = mockDataManager;

    [PushwooshConfig setTags:tags];

    OCMVerifyAll(mockDataManager);
}

/// Verifies that setTags:completion: forwards both arguments to PWManagerBridge.dataManager.
- (void)testSetTagsWithCompletion_forwardsToDataManager {
    id mockDataManager = OCMClassMock([PWDataManager class]);
    NSDictionary *tags = @{@"k": @"v"};
    void (^completion)(NSError *) = ^(NSError *error) {};
    OCMExpect([mockDataManager setTags:tags withCompletion:completion]);
    [PWManagerBridge shared].dataManager = mockDataManager;

    [PushwooshConfig setTags:tags completion:completion];

    OCMVerifyAll(mockDataManager);
}

#pragma mark - registerForPushNotifications forwarding

/// Verifies that registerForPushNotifications forwards a nil-completion to PWManagerBridge.pushNotificationManager.
- (void)testRegisterForPushNotifications_forwardsNilCompletion {
    id mockPushManager = OCMClassMock([PWPushNotificationsManager class]);
    OCMExpect([mockPushManager registerForPushNotificationsWithCompletion:[OCMArg isNil]]);
    [PWManagerBridge shared].pushNotificationManager = mockPushManager;

    [PushwooshConfig registerForPushNotifications];

    OCMVerifyAll(mockPushManager);
}

/// Verifies that registerForPushNotificationsWithCompletion: forwards the completion to the push manager.
- (void)testRegisterForPushNotificationsWithCompletion_forwardsCompletion {
    id mockPushManager = OCMClassMock([PWPushNotificationsManager class]);
    PushwooshRegistrationHandler completion = ^(NSString *token, NSError *error) {};
    OCMExpect([mockPushManager registerForPushNotificationsWithCompletion:completion]);
    [PWManagerBridge shared].pushNotificationManager = mockPushManager;

    [PushwooshConfig registerForPushNotificationsWithCompletion:completion];

    OCMVerifyAll(mockPushManager);
}

#pragma mark - registerSmsNumber / registerWhatsappNumber trim

/// Verifies that registerSmsNumber trims input and forwards the trimmed value to the push manager.
- (void)testRegisterSmsNumber_forwardsTrimmedValue {
    id mockPushManager = OCMClassMock([PWPushNotificationsManager class]);
    OCMExpect([mockPushManager registerSmsNumber:@"+12345"]);
    [PWManagerBridge shared].pushNotificationManager = mockPushManager;

    [PushwooshConfig registerSmsNumber:@"  +12345  "];

    OCMVerifyAll(mockPushManager);
}

/// Verifies that registerWhatsappNumber trims input and forwards the trimmed value to the push manager.
- (void)testRegisterWhatsappNumber_forwardsTrimmedValue {
    id mockPushManager = OCMClassMock([PWPushNotificationsManager class]);
    OCMExpect([mockPushManager registerWhatsappNumber:@"+12345"]);
    [PWManagerBridge shared].pushNotificationManager = mockPushManager;

    [PushwooshConfig registerWhatsappNumber:@"  +12345  "];

    OCMVerifyAll(mockPushManager);
}

#pragma mark - setLanguage / getLanguage

/// Verifies that setLanguage persists a trimmed value in PWPreferences and getLanguage reads it back.
- (void)testSetLanguage_persistsTrimmedValueAndGetLanguageReadsItBack {
    [PushwooshConfig setLanguage:@"  fr  "];

    XCTAssertEqualObjects([PushwooshConfig getLanguage], @"fr");
    XCTAssertEqualObjects([PWPreferences preferences].language, @"fr");
}

#pragma mark - showPushnotificationAlert round trip

/// Verifies that setShowPushnotificationAlert writes through both PWPreferences and PWManagerBridge, and getShowPushnotificationAlert reads back.
- (void)testShowPushnotificationAlert_roundTrip {
    [PushwooshConfig setShowPushnotificationAlert:NO];

    XCTAssertFalse([PushwooshConfig getShowPushnotificationAlert]);
    XCTAssertFalse([PWPreferences preferences].showForegroundNotifications);
    XCTAssertFalse([PWManagerBridge shared].showPushnotificationAlert);

    [PushwooshConfig setShowPushnotificationAlert:YES];

    XCTAssertTrue([PushwooshConfig getShowPushnotificationAlert]);
    XCTAssertTrue([PWPreferences preferences].showForegroundNotifications);
    XCTAssertTrue([PWManagerBridge shared].showPushnotificationAlert);
}

#pragma mark - delegate round trip

/// Verifies that setDelegate stores the delegate on PWManagerBridge and getDelegate returns the same instance.
- (void)testSetDelegate_storesAndReadsBack {
    id delegate = [NSObject new];

    [PushwooshConfig setDelegate:delegate];

    XCTAssertEqual([PushwooshConfig getDelegate], delegate);
}

#pragma mark - getUserId

/// Verifies that getUserId reads from PWPreferences.
- (void)testGetUserId_readsPreferences {
    NSString *original = [PWPreferences preferences].userId;
    [PWPreferences preferences].userId = @"read-back-user";

    XCTAssertEqualObjects([PushwooshConfig getUserId], @"read-back-user");

    [PWPreferences preferences].userId = original;
}

#pragma mark - setAdvertisingId edge cases

/// Verifies that the zero-uuid sentinel (ATT opt-out) is normalized to nil and dispatched as a clear request when a prior IDFA was set, leaving prefs untouched until the network round-trip succeeds.
- (void)testSetAdvertisingId_zeroUUID_normalizedToNil_sendsClearRequest {
    if (![[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        [[PWServerCommunicationManager sharedInstance] startServerCommunication];
    }
    [PWPreferences preferences].advertisingId = @"prior-idfa-value";
    id reqManager = [self mockRequestManager];
    OCMExpect([reqManager sendRequest:[OCMArg checkWithBlock:^BOOL(id request) {
        return [[request valueForKey:@"advertisingId"] length] == 0;
    }] completion:[OCMArg any]]);

    [PushwooshConfig setAdvertisingId:@"00000000-0000-0000-0000-000000000000"];

    OCMVerifyAll(reqManager);
    XCTAssertEqualObjects([PWPreferences preferences].advertisingId, @"prior-idfa-value", @"prefs.advertisingId must not be cleared without a successful network round-trip");
}

/// Verifies that setAdvertisingId dispatches no request when ServerCommunication is disabled.
- (void)testSetAdvertisingId_serverCommunicationDisabled_doesNotSendRequest {
    BOOL wasAllowed = [[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed];
    [[PWServerCommunicationManager sharedInstance] stopServerCommunication];
    id reqManager = [self mockRequestManager];
    OCMReject([reqManager sendRequest:[OCMArg any] completion:[OCMArg any]]);

    [PushwooshConfig setAdvertisingId:@"5DDA4E0F-1234-1234-1234-DEADBEEF0000"];

    OCMVerifyAll(reqManager);

    if (wasAllowed) {
        [[PWServerCommunicationManager sharedInstance] startServerCommunication];
    }
}

/// Verifies that setAdvertisingId with the same value as already-persisted dispatches no second network request.
- (void)testSetAdvertisingId_sameAsPersisted_doesNotSendRequest {
    if (![[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        [[PWServerCommunicationManager sharedInstance] startServerCommunication];
    }
    [PWPreferences preferences].advertisingId = @"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE";
    id reqManager = [self mockRequestManager];
    OCMReject([reqManager sendRequest:[OCMArg any] completion:[OCMArg any]]);

    [PushwooshConfig setAdvertisingId:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"];

    OCMVerifyAll(reqManager);
}

#pragma mark - setReverseProxy trim + gating

/// Verifies that setReverseProxy with whitespace-only URL is ignored.
- (void)testSetReverseProxy_whitespaceOnly_isIgnored {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig allowReverseProxy]).andReturn(YES);
    id mockPushManager = OCMClassMock([PWPushNotificationsManager class]);
    OCMReject([mockPushManager setReverseProxy:[OCMArg any] headers:[OCMArg any]]);
    [PWManagerBridge shared].pushNotificationManager = mockPushManager;

    [PushwooshConfig setReverseProxy:@"   " headers:nil];

    OCMVerifyAll(mockPushManager);

    [mockConfig stopMocking];
}

/// Verifies that setReverseProxy trims a valid URL and forwards through PWManagerBridge (which then enforces the allowReverseProxy gate).
- (void)testSetReverseProxy_validUrl_forwardsTrimmedThroughBridge {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig allowReverseProxy]).andReturn(YES);
    id mockPushManager = OCMClassMock([PWPushNotificationsManager class]);
    OCMExpect([mockPushManager setReverseProxy:@"https://proxy.example.com/" headers:nil]);
    [PWManagerBridge shared].pushNotificationManager = mockPushManager;

    [PushwooshConfig setReverseProxy:@"  https://proxy.example.com/  " headers:nil];

    OCMVerifyAll(mockPushManager);

    [mockConfig stopMocking];
}

#pragma mark - sendBadges forwarding

/// Verifies that sendBadges forwards the value to PWManagerBridge.dataManager as a tag.
- (void)testSendBadges_forwardsToDataManager {
    id mockDataManager = OCMClassMock([PWDataManager class]);
    OCMExpect([mockDataManager setTags:@{@"badge": @7}]);
    [PWManagerBridge shared].dataManager = mockDataManager;

    [PushwooshConfig sendBadges:7];

    OCMVerifyAll(mockDataManager);
}

#pragma mark - Static delegation methods

/// Verifies that version returns the same string as PWManagerBridge.version.
- (void)testVersion_matchesManagerBridgeVersion {
    XCTAssertEqualObjects([PushwooshConfig version], [PWManagerBridge version]);
}

/// Verifies that handlePushReceived: forwards to PWManagerBridge with autoAcceptAllowed=YES (default).
- (void)testHandlePushReceived_forwardsToBridgeWithAutoAcceptYes {
    id mockPushManager = OCMClassMock([PWPushNotificationsManager class]);
    NSDictionary *userInfo = @{@"aps": @{}};
    OCMExpect([mockPushManager handlePushReceived:userInfo autoAcceptAllowed:YES]).andReturn(YES);
    [PWManagerBridge shared].pushNotificationManager = mockPushManager;

    BOOL result = [PushwooshConfig handlePushReceived:userInfo];

    XCTAssertTrue(result);
    OCMVerifyAll(mockPushManager);
}

#pragma mark - getLaunchNotification

/// Verifies that getLaunchNotification reads through to PWManagerBridge.launchNotification.
- (void)testGetLaunchNotification_readsManagerBridge {
    NSDictionary *prior = [PWManagerBridge shared].launchNotification;
    NSDictionary *payload = @{@"aps": @{@"alert": @"hi"}};
    [PWManagerBridge shared].launchNotification = payload;

    XCTAssertEqualObjects([PushwooshConfig getLaunchNotification], payload);

    [PWManagerBridge shared].launchNotification = prior;
}

#pragma mark - additionalAuthorizationOptions round trip

/// Verifies that setAdditionalAuthorizationOptions stores via PWManagerBridge and getAdditionalAuthorizationOptions reads back.
- (void)testAdditionalAuthorizationOptions_roundTrip {
    UNAuthorizationOptions prior = [PushwooshConfig getAdditionalAuthorizationOptions];

    [PushwooshConfig setAdditionalAuthorizationOptions:UNAuthorizationOptionProvisional];

    XCTAssertEqual([PushwooshConfig getAdditionalAuthorizationOptions], UNAuthorizationOptionProvisional);
    XCTAssertEqual([PWManagerBridge shared].additionalAuthorizationOptions, UNAuthorizationOptionProvisional);

    [PushwooshConfig setAdditionalAuthorizationOptions:prior];
}

@end
