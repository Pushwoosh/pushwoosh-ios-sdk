#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWManagerBridge.h"
#import <PushwooshCore/PushwooshCore.h>
#import "PWPreferences.h"
#import "PWConfig.h"
#import "PWDataManager.h"
#import "PWPushNotificationsManager.h"
#import "PWInAppManager.h"

#if TARGET_OS_IOS || TARGET_OS_OSX
#import "PWPurchaseManager.h"
#endif

@interface PWManagerBridge (Test)

@property (nonatomic, copy) NSDictionary *launchNotification;

@end

@interface PWManagerBridgeTest : XCTestCase

@property (nonatomic, strong) PWManagerBridge *bridge;
@property (nonatomic, strong) PWDataManager *originalDataManager;
@property (nonatomic, strong) PWPushNotificationsManager *originalPushNotificationManager;
@property (nonatomic, strong) PWInAppManager *originalInAppManager;
#if TARGET_OS_IOS || TARGET_OS_OSX
@property (nonatomic, strong) PWPurchaseManager *originalPurchaseManager;
#endif
@property (nonatomic, copy) void (^originalSetEmailBlock)(NSString *);
@property (nonatomic, copy) void (^originalSendTransactionsBlock)(NSArray *);
@property (nonatomic, copy) NSDictionary *originalLaunchNotification;

@end

@implementation PWManagerBridgeTest

- (void)setUp {
    [super setUp];
    _bridge = [PWManagerBridge shared];
    _originalDataManager = _bridge.dataManager;
    _originalPushNotificationManager = _bridge.pushNotificationManager;
#if TARGET_OS_IOS || TARGET_OS_TV
    _originalInAppManager = _bridge.inAppManager;
#endif
#if TARGET_OS_IOS || TARGET_OS_OSX
    _originalPurchaseManager = _bridge.purchaseManager;
#endif
    _originalSetEmailBlock = _bridge.setEmailBlock;
    _originalSendTransactionsBlock = _bridge.sendTransactionsBlock;
    _originalLaunchNotification = _bridge.launchNotification;
}

- (void)tearDown {
    _bridge.dataManager = _originalDataManager;
    _bridge.pushNotificationManager = _originalPushNotificationManager;
#if TARGET_OS_IOS || TARGET_OS_TV
    _bridge.inAppManager = _originalInAppManager;
#endif
#if TARGET_OS_IOS || TARGET_OS_OSX
    _bridge.purchaseManager = _originalPurchaseManager;
#endif
    _bridge.setEmailBlock = _originalSetEmailBlock;
    _bridge.sendTransactionsBlock = _originalSendTransactionsBlock;
    _bridge.launchNotification = _originalLaunchNotification;
    [super tearDown];
}

#pragma mark - Singleton & init defaults

/// Verifies that shared returns the same singleton instance across calls.
- (void)testSharedIsSingleton {
    PWManagerBridge *a = [PWManagerBridge shared];
    PWManagerBridge *b = [PWManagerBridge shared];

    XCTAssertNotNil(a);
    XCTAssertEqual(a, b);
}

/// Verifies that a freshly initialized bridge has showPushnotificationAlert=YES and additionalAuthorizationOptions=0.
- (void)testInitDefaults {
    PWManagerBridge *fresh = [[PWManagerBridge alloc] init];

    XCTAssertTrue(fresh.showPushnotificationAlert);
    XCTAssertEqual(fresh.additionalAuthorizationOptions, 0);
}

#pragma mark - Block-based delegation

/// Verifies that setEmail invokes setEmailBlock with the supplied email argument.
- (void)testSetEmail_invokesBlockWithEmail {
    __block NSString *captured = nil;
    self.bridge.setEmailBlock = ^(NSString *email) {
        captured = email;
    };

    [self.bridge setEmail:@"test@example.com"];

    XCTAssertEqualObjects(captured, @"test@example.com");
}

/// Verifies that setEmail with nil setEmailBlock is a safe no-op.
- (void)testSetEmail_nilBlock_doesNotCrash {
    self.bridge.setEmailBlock = nil;

    XCTAssertNoThrow([self.bridge setEmail:@"test@example.com"]);
}

/// Verifies that sendSKPaymentTransactions invokes sendTransactionsBlock with the supplied array.
- (void)testSendSKPaymentTransactions_invokesBlockWithArray {
    NSArray *transactions = @[@"tx1", @"tx2"];
    __block NSArray *captured = nil;
    self.bridge.sendTransactionsBlock = ^(NSArray *tx) {
        captured = tx;
    };

    [self.bridge sendSKPaymentTransactions:transactions];

    XCTAssertEqualObjects(captured, transactions);
}

/// Verifies that sendSKPaymentTransactions with nil sendTransactionsBlock is a safe no-op.
- (void)testSendSKPaymentTransactions_nilBlock_doesNotCrash {
    self.bridge.sendTransactionsBlock = nil;

    XCTAssertNoThrow([self.bridge sendSKPaymentTransactions:@[]]);
}

#pragma mark - Preferences-backed getters

/// Verifies that getPushToken returns the token currently stored in PWPreferences.
- (void)testGetPushToken_returnsPreferencesValue {
    id mockPrefs = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPrefs pushToken]).andReturn(@"test-push-token");

    XCTAssertEqualObjects([self.bridge getPushToken], @"test-push-token");

    [mockPrefs stopMocking];
}

/// Verifies that getHWID returns the hwid currently stored in PWPreferences.
- (void)testGetHWID_returnsPreferencesValue {
    id mockPrefs = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPrefs hwid]).andReturn(@"test-hwid-12345");

    XCTAssertEqualObjects([self.bridge getHWID], @"test-hwid-12345");

    [mockPrefs stopMocking];
}

/// Verifies that appCode returns the appCode currently stored in PWPreferences.
- (void)testAppCode_returnsPreferencesValue {
    id mockPrefs = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPrefs appCode]).andReturn(@"TEST-CODE-12345");

    XCTAssertEqualObjects([self.bridge appCode], @"TEST-CODE-12345");

    [mockPrefs stopMocking];
}

#pragma mark - Nil-safety on optional managers

/// Verifies that getCustomPushData returns nil when pushNotificationManager is not set.
- (void)testGetCustomPushData_nilManager_returnsNil {
    self.bridge.pushNotificationManager = nil;

    XCTAssertNil([self.bridge getCustomPushData:@{@"u": @"data"}]);
}

/// Verifies that getCustomPushData forwards the call to pushNotificationManager and returns its result.
- (void)testGetCustomPushData_forwardsToManager {
    id mockManager = OCMClassMock([PWPushNotificationsManager class]);
    NSDictionary *payload = @{@"aps": @{}, @"u": @"data"};
    OCMStub([mockManager getCustomPushData:payload]).andReturn(@"custom-data");
    self.bridge.pushNotificationManager = mockManager;

    XCTAssertEqualObjects([self.bridge getCustomPushData:payload], @"custom-data");
}

/// Verifies that handlePushReceived:autoAcceptAllowed: returns NO when pushNotificationManager is nil.
- (void)testHandlePushReceived_nilManager_returnsNo {
    self.bridge.pushNotificationManager = nil;

    BOOL result = [self.bridge handlePushReceived:@{@"aps": @{}} autoAcceptAllowed:YES];

    XCTAssertFalse(result);
}

/// Verifies that handlePushReceived (no autoAcceptAllowed arg) implicitly passes YES to the underlying manager.
- (void)testHandlePushReceived_defaultAutoAcceptIsYes {
    id mockManager = OCMClassMock([PWPushNotificationsManager class]);
    NSDictionary *payload = @{@"aps": @{}};
    OCMExpect([mockManager handlePushReceived:payload autoAcceptAllowed:YES]).andReturn(YES);
    self.bridge.pushNotificationManager = mockManager;

    [self.bridge handlePushReceived:payload];

    OCMVerifyAll(mockManager);
}

#pragma mark - Forwarding to subsystem managers

/// Verifies that handlePushRegistration forwards the device token to pushNotificationManager.
- (void)testHandlePushRegistration_forwardsToManager {
    id mockManager = OCMClassMock([PWPushNotificationsManager class]);
    NSData *token = [@"deadbeef" dataUsingEncoding:NSUTF8StringEncoding];
    OCMExpect([mockManager handlePushRegistration:token]);
    self.bridge.pushNotificationManager = mockManager;

    [self.bridge handlePushRegistration:token];

    OCMVerifyAll(mockManager);
}

/// Verifies that handlePushRegistrationFailure forwards the error to pushNotificationManager.
- (void)testHandlePushRegistrationFailure_forwardsToManager {
    id mockManager = OCMClassMock([PWPushNotificationsManager class]);
    NSError *error = [NSError errorWithDomain:@"test" code:42 userInfo:nil];
    OCMExpect([mockManager handlePushRegistrationFailure:error]);
    self.bridge.pushNotificationManager = mockManager;

    [self.bridge handlePushRegistrationFailure:error];

    OCMVerifyAll(mockManager);
}

/// Verifies that setTags forwards the dictionary to dataManager.
- (void)testSetTags_forwardsToDataManager {
    id mockDataManager = OCMClassMock([PWDataManager class]);
    NSDictionary *tags = @{@"k": @"v"};
    OCMExpect([mockDataManager setTags:tags]);
    self.bridge.dataManager = mockDataManager;

    [self.bridge setTags:tags];

    OCMVerifyAll(mockDataManager);
}

/// Verifies that setTags:withCompletion: forwards both the dictionary and completion to dataManager.
- (void)testSetTagsWithCompletion_forwardsToDataManager {
    id mockDataManager = OCMClassMock([PWDataManager class]);
    NSDictionary *tags = @{@"k": @"v"};
    void (^completion)(NSError *) = ^(NSError *error) {};
    OCMExpect([mockDataManager setTags:tags withCompletion:completion]);
    self.bridge.dataManager = mockDataManager;

    [self.bridge setTags:tags withCompletion:completion];

    OCMVerifyAll(mockDataManager);
}

/// Verifies that setEmailTags:forEmail: forwards to dataManager with a nil completion block.
- (void)testSetEmailTags_withoutCompletion_forwardsNilCompletion {
    id mockDataManager = OCMClassMock([PWDataManager class]);
    NSDictionary *tags = @{@"k": @"v"};
    OCMExpect([mockDataManager setEmailTags:tags forEmail:@"a@b.c" withCompletion:[OCMArg isNil]]);
    self.bridge.dataManager = mockDataManager;

    [self.bridge setEmailTags:tags forEmail:@"a@b.c"];

    OCMVerifyAll(mockDataManager);
}

/// Verifies that setTags is a safe no-op when dataManager is nil.
- (void)testSetTags_nilDataManager_doesNotCrash {
    self.bridge.dataManager = nil;

    XCTAssertNoThrow([self.bridge setTags:@{@"k": @"v"}]);
}

/// Verifies that registerForPushNotifications (no args) forwards a nil completion to pushNotificationManager.
- (void)testRegisterForPushNotifications_forwardsNilCompletion {
    id mockManager = OCMClassMock([PWPushNotificationsManager class]);
    OCMExpect([mockManager registerForPushNotificationsWithCompletion:[OCMArg isNil]]);
    self.bridge.pushNotificationManager = mockManager;

    [self.bridge registerForPushNotifications];

    OCMVerifyAll(mockManager);
}

/// Verifies that unregisterForPushNotifications forwards the completion handler to pushNotificationManager.
- (void)testUnregisterForPushNotifications_forwardsCompletion {
    id mockManager = OCMClassMock([PWPushNotificationsManager class]);
    void (^completion)(NSError *) = ^(NSError *error) {};
    OCMExpect([mockManager unregisterForPushNotificationsWithCompletion:completion]);
    self.bridge.pushNotificationManager = mockManager;

    [self.bridge unregisterForPushNotificationsWithCompletion:completion];

    OCMVerifyAll(mockManager);
}

/// Verifies that registerSmsNumber forwards the number to pushNotificationManager.
- (void)testRegisterSmsNumber_forwardsToManager {
    id mockManager = OCMClassMock([PWPushNotificationsManager class]);
    OCMExpect([mockManager registerSmsNumber:@"+1234567890"]);
    self.bridge.pushNotificationManager = mockManager;

    [self.bridge registerSmsNumber:@"+1234567890"];

    OCMVerifyAll(mockManager);
}

/// Verifies that registerWhatsappNumber forwards the number to pushNotificationManager.
- (void)testRegisterWhatsappNumber_forwardsToManager {
    id mockManager = OCMClassMock([PWPushNotificationsManager class]);
    OCMExpect([mockManager registerWhatsappNumber:@"+1234567890"]);
    self.bridge.pushNotificationManager = mockManager;

    [self.bridge registerWhatsappNumber:@"+1234567890"];

    OCMVerifyAll(mockManager);
}

/// Verifies that registerForPushNotificationsWith:tags persists tags via PWPreferences.customTags and then registers.
- (void)testRegisterForPushNotificationsWithTags_persistsTagsThenRegisters {
    NSDictionary *tags = @{@"interest": @"sports"};
    id mockPrefs = OCMPartialMock([PWPreferences preferences]);
    OCMExpect([mockPrefs setCustomTags:tags]);
    id mockManager = OCMClassMock([PWPushNotificationsManager class]);
    OCMExpect([mockManager registerForPushNotificationsWithCompletion:[OCMArg isNil]]);
    self.bridge.pushNotificationManager = mockManager;

    [self.bridge registerForPushNotificationsWith:tags];

    OCMVerifyAll(mockPrefs);
    OCMVerifyAll(mockManager);

    [mockPrefs stopMocking];
}

#pragma mark - Reverse proxy gating

/// Verifies that setReverseProxy is IGNORED when PWConfig.allowReverseProxy is NO.
- (void)testSetReverseProxy_disallowedByConfig_isIgnored {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig allowReverseProxy]).andReturn(NO);
    id mockManager = OCMClassMock([PWPushNotificationsManager class]);
    OCMReject([mockManager setReverseProxy:[OCMArg any] headers:[OCMArg any]]);
    self.bridge.pushNotificationManager = mockManager;

    [self.bridge setReverseProxy:@"https://proxy.example.com/" headers:nil];

    OCMVerifyAll(mockManager);

    [mockConfig stopMocking];
}

/// Verifies that setReverseProxy is forwarded to pushNotificationManager when PWConfig.allowReverseProxy is YES.
- (void)testSetReverseProxy_allowedByConfig_forwardsToManager {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig allowReverseProxy]).andReturn(YES);
    id mockManager = OCMClassMock([PWPushNotificationsManager class]);
    NSDictionary *headers = @{@"X-Custom": @"v"};
    OCMExpect([mockManager setReverseProxy:@"https://proxy.example.com/" headers:headers]);
    self.bridge.pushNotificationManager = mockManager;

    [self.bridge setReverseProxy:@"https://proxy.example.com/" headers:headers];

    OCMVerifyAll(mockManager);

    [mockConfig stopMocking];
}

#pragma mark - User management

#if TARGET_OS_IOS || TARGET_OS_TV

/// Verifies that setUserId (no completion) forwards to inAppManager.
- (void)testSetUserId_forwardsToInAppManager {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    OCMExpect([mockInApp setUserId:@"user-123"]);
    self.bridge.inAppManager = mockInApp;

    [self.bridge setUserId:@"user-123"];

    OCMVerifyAll(mockInApp);
}

/// Verifies that setUserId:completion: forwards both userId and completion to inAppManager.
- (void)testSetUserIdWithCompletion_forwardsToInAppManager {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    void (^completion)(NSError *) = ^(NSError *error) {};
    OCMExpect([mockInApp setUserId:@"user-123" completion:completion]);
    self.bridge.inAppManager = mockInApp;

    [self.bridge setUserId:@"user-123" completion:completion];

    OCMVerifyAll(mockInApp);
}

/// Verifies that setEmails forwards to inAppManager with a nil completion when called without one.
- (void)testSetEmails_withoutCompletion_forwardsNilCompletion {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    NSArray *emails = @[@"a@b.c", @"x@y.z"];
    OCMExpect([mockInApp setEmails:emails completion:[OCMArg isNil]]);
    self.bridge.inAppManager = mockInApp;

    [self.bridge setEmails:emails];

    OCMVerifyAll(mockInApp);
}

/// Verifies that setUser:email:completion: collapses the single email into an array and forwards via setUser:emails:completion:.
- (void)testSetUserSingleEmail_collapsesToArray {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    void (^completion)(NSError *) = ^(NSError *error) {};
    OCMExpect([mockInApp setUser:@"user-123" emails:@[@"a@b.c"] completion:completion]);
    self.bridge.inAppManager = mockInApp;

    [self.bridge setUser:@"user-123" email:@"a@b.c" completion:completion];

    OCMVerifyAll(mockInApp);
}

/// Verifies that mergeUserId:to:doMerge:completion: forwards all four args to inAppManager.
- (void)testMergeUserId_forwardsToInAppManager {
    id mockInApp = OCMClassMock([PWInAppManager class]);
    void (^completion)(NSError *) = ^(NSError *error) {};
    OCMExpect([mockInApp mergeUserId:@"old" to:@"new" doMerge:YES completion:completion]);
    self.bridge.inAppManager = mockInApp;

    [self.bridge mergeUserId:@"old" to:@"new" doMerge:YES completion:completion];

    OCMVerifyAll(mockInApp);
}

/// Verifies that setUserId is a safe no-op when inAppManager is nil.
- (void)testSetUserId_nilInAppManager_doesNotCrash {
    self.bridge.inAppManager = nil;

    XCTAssertNoThrow([self.bridge setUserId:@"user-123"]);
}

#endif

#pragma mark - Badge

/// Verifies that sendBadges writes the badge value as a "badge" tag through dataManager.
- (void)testSendBadges_writesBadgeAsTag {
    id mockDataManager = OCMClassMock([PWDataManager class]);
    OCMExpect([mockDataManager setTags:@{@"badge": @42}]);
    self.bridge.dataManager = mockDataManager;

    [self.bridge sendBadges:42];

    OCMVerifyAll(mockDataManager);
}

/// Verifies that sendBadges is a safe no-op when dataManager is nil.
- (void)testSendBadges_nilDataManager_doesNotCrash {
    self.bridge.dataManager = nil;

    XCTAssertNoThrow([self.bridge sendBadges:1]);
}

#pragma mark - Server communication

/// Verifies that isServerCommunicationAllowed reflects the underlying PWServerCommunicationManager state.
- (void)testIsServerCommunicationAllowed_reflectsServerCommManagerState {
    BOOL initial = [self.bridge isServerCommunicationAllowed];

    [self.bridge stopServerCommunication];
    XCTAssertFalse([self.bridge isServerCommunicationAllowed]);

    [self.bridge startServerCommunication];
    XCTAssertTrue([self.bridge isServerCommunicationAllowed]);

    if (!initial) {
        [self.bridge stopServerCommunication];
    }
}

#pragma mark - Purchases (iOS only)

#if TARGET_OS_IOS

/// Verifies that sendPurchase forwards all four args (id, price, currency, date) to purchaseManager.
- (void)testSendPurchase_forwardsToPurchaseManager {
    id mockPurchase = OCMClassMock([PWPurchaseManager class]);
    NSDecimalNumber *price = [NSDecimalNumber decimalNumberWithString:@"9.99"];
    NSDate *now = [NSDate date];
    OCMExpect([mockPurchase sendPurchase:@"product-1" withPrice:price currencyCode:@"USD" andDate:now]);
    self.bridge.purchaseManager = mockPurchase;

    [self.bridge sendPurchase:@"product-1" withPrice:price currencyCode:@"USD" andDate:now];

    OCMVerifyAll(mockPurchase);
}

/// Verifies that sendPurchase is a safe no-op when purchaseManager is nil.
- (void)testSendPurchase_nilPurchaseManager_doesNotCrash {
    self.bridge.purchaseManager = nil;

    XCTAssertNoThrow([self.bridge sendPurchase:@"p" withPrice:[NSDecimalNumber zero] currencyCode:@"USD" andDate:[NSDate date]]);
}

#endif

#pragma mark - Static utility methods

/// Verifies that version returns the canonical PUSHWOOSH_VERSION string.
- (void)testVersion_matchesPushwooshVersionMacro {
    NSString *version = [PWManagerBridge version];

    XCTAssertEqualObjects(version, PUSHWOOSH_VERSION);
    NSArray *parts = [version componentsSeparatedByString:@"."];
    XCTAssertGreaterThanOrEqual(parts.count, 2, @"version should be at least X.Y, got: %@", version);
}

/// Verifies that getRemoteNotificationStatus forwards to PWPushNotificationsManager and returns its dictionary verbatim.
- (void)testGetRemoteNotificationStatus_delegatesToPushManager {
    id mockPushManager = OCMClassMock([PWPushNotificationsManager class]);
    NSDictionary *status = @{@"pushAlert": @1, @"pushSound": @0, @"pushBadge": @1};
    OCMStub([mockPushManager getRemoteNotificationStatus]).andReturn(status);

    NSDictionary *result = [PWManagerBridge getRemoteNotificationStatus];

    XCTAssertEqualObjects(result, status);

    [mockPushManager stopMocking];
}

#pragma mark - Launch notification

/// Verifies that launchNotification can be set and read back as a copy of the original dictionary.
- (void)testLaunchNotification_roundTrip {
    NSDictionary *payload = @{@"aps": @{@"alert": @"hello"}, @"p": @"hash"};

    self.bridge.launchNotification = payload;

    XCTAssertEqualObjects(self.bridge.launchNotification, payload);
}

/// Verifies that launchNotification is declared "copy" — assigning a mutable dict and mutating it must NOT mutate the stored value.
- (void)testLaunchNotification_isCopiedNotRetained {
    NSMutableDictionary *mutable = [@{@"aps": @{@"alert": @"hello"}} mutableCopy];
    self.bridge.launchNotification = mutable;

    [mutable setObject:@"injected" forKey:@"evil"];

    XCTAssertNil(self.bridge.launchNotification[@"evil"], @"launchNotification must be copied on set, not retained");
}

@end
