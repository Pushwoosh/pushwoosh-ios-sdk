//
//  PushwooshTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PushwooshFramework.h"
#import "PWPreferences.h"
#import "PWInAppManager.h"
#import "PWConfig.h"
#import "PWPushNotificationsManager.h"
#import <PushwooshCore/PWDataManager.h>
#import <PushwooshCore/PWManagerBridge.h>
#import "PWSdkStateProvider.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface PWSdkStateProvider (PushwooshTest)

- (void)resetForTesting;
- (void)setReady;

@end

@interface PWMessagingSenderSpy : NSObject <PWMessagingDelegate>

@property (nonatomic, strong) XCTestExpectation *received;
@property (nonatomic, strong) XCTestExpectation *opened;
@property (nonatomic, strong) id receivedSender;
@property (nonatomic, strong) id openedSender;

@end

@implementation PWMessagingSenderSpy

- (void)pushwoosh:(Pushwoosh *)pushwoosh onMessageReceived:(PWMessage *)message {
    self.receivedSender = pushwoosh;
    [self.received fulfill];
}

- (void)pushwoosh:(Pushwoosh *)pushwoosh onMessageOpened:(PWMessage *)message {
    self.openedSender = pushwoosh;
    [self.opened fulfill];
}

@end

@interface Pushwoosh (TEST)

+ (void)destroy;
- (instancetype)initWithApplicationCode:(NSString *)appCode;

@property (nonatomic) PWDataManager *dataManager;
@property (nonatomic) PWInAppManager *inAppManager;
@property (nonatomic) PWPushNotificationsManager *pushNotificationManager;

@end

@interface PushwooshTest : XCTestCase

@property (nonatomic) Pushwoosh *pushwoosh;

@end

@implementation PushwooshTest

- (void)setUp {
    self.pushwoosh = [Pushwoosh sharedInstance];
}

- (void)tearDown {
}

- (void)testInitWithApplicationCode {
    id mockPWInAppManager = OCMClassMock([PWInAppManager class]);
    OCMStub([mockPWInAppManager sharedManager]);
    id mockPWConfig = OCMClassMock([PWConfig class]);
    OCMStub([mockPWConfig config]);

    id result = [self.pushwoosh initWithApplicationCode:@"DC533-F5DA4"];

    XCTAssert(result);
    XCTAssertEqual([PWPreferences preferences].appCode, @"DC533-F5DA4");
    OCMVerify([mockPWInAppManager sharedManager]);
    OCMVerify([mockPWConfig config]);
    [mockPWInAppManager stopMocking];
    [mockPWConfig stopMocking];
}

/// Verifies that Pushwoosh.configure brings up the shared Pushwoosh instance when nothing has created it yet.
- (void)testConfigureCreatesSharedInstance {
    [Pushwoosh destroy];
    [PWManagerBridge shared].messagingSender = nil;

    (void)[Pushwoosh configure];

    id createdInstance = [PWManagerBridge shared].messagingSender;
    XCTAssertNotNil(createdInstance);
    XCTAssertEqual(createdInstance, [Pushwoosh sharedInstance]);
}

/// Verifies that initializeWithAppCode with the stored app code brings up the shared Pushwoosh instance.
- (void)testInitializeWithStoredAppCodeCreatesSharedInstance {
    [PWPreferences preferences].appCode = @"DC533-F5DA4";
    [Pushwoosh destroy];
    [PWManagerBridge shared].messagingSender = nil;

    [Pushwoosh initializeWithAppCode:@"DC533-F5DA4"];

    id createdInstance = [PWManagerBridge shared].messagingSender;
    XCTAssertNotNil(createdInstance);
    XCTAssertEqual(createdInstance, [Pushwoosh sharedInstance]);
}

- (void)testCheckTagsAreExistWhenRegisterForNotifyCalled {
    NSDictionary *customTags = @{@"k1":@"v1", @"k2": @"v2"};

    [[Pushwoosh sharedInstance] registerForPushNotificationsWith:customTags
                                                      completion:^(NSString * _Nullable token, NSError * _Nullable error) {}];

    XCTAssertEqual(customTags, [[PWPreferences preferences] customTags]);
}

- (void)testCheckCustomTagsNullIfPassedNull {
    [[Pushwoosh sharedInstance] registerForPushNotificationsWith:nil];

    XCTAssertNil([[PWPreferences preferences] customTags]);
}


- (void)testSetLanguageSavesToPreferences {
    [self.pushwoosh setLanguage:@"ru"];

    XCTAssertEqualObjects([PWPreferences preferences].language, @"ru");
}

- (void)testGetLanguageReturnsPreferencesValue {
    [PWPreferences preferences].language = @"en";

    NSString *language = [self.pushwoosh language];

    XCTAssertEqualObjects(language, @"en");
}

- (void)testShowPushnotificationAlertGetterReturnsPreferencesValue {
    [PWPreferences preferences].showForegroundNotifications = YES;

    BOOL result = [self.pushwoosh showPushnotificationAlert];

    XCTAssertTrue(result);
}

- (void)testShowPushnotificationAlertSetterSavesToPreferences {
    [self.pushwoosh setShowPushnotificationAlert:NO];

    XCTAssertFalse([PWPreferences preferences].showForegroundNotifications);
}

- (void)testShowPushnotificationAlertSetterUpdatesManagerBridge {
    [self.pushwoosh setShowPushnotificationAlert:YES];

    XCTAssertTrue([PWManagerBridge shared].showPushnotificationAlert);
}

- (void)testGetHWIDReturnsPreferencesValue {
    NSString *hwid = [self.pushwoosh getHWID];

    XCTAssertEqualObjects(hwid, [PWPreferences preferences].hwid);
}

- (void)testGetUserIdReturnsPreferencesValue {
    [PWPreferences preferences].userId = @"test_user";

    NSString *userId = [self.pushwoosh getUserId];

    XCTAssertEqualObjects(userId, @"test_user");
}

- (void)testApplicationCodeReturnsPreferencesValue {
    NSString *currentAppCode = [PWPreferences preferences].appCode;

    NSString *appCode = [self.pushwoosh applicationCode];

    XCTAssertEqualObjects(appCode, currentAppCode);
}

- (void)testGetPushTokenReturnsPreferencesValue {
    [PWPreferences preferences].pushToken = @"test_token";

    NSString *token = [self.pushwoosh getPushToken];

    XCTAssertEqualObjects(token, @"test_token");
}

- (void)testVersionReturnsCorrectValue {
    NSString *version = [Pushwoosh version];

    XCTAssertNotNil(version);
    XCTAssertTrue(version.length > 0);
}

- (void)testPWTagsBuilderIncrementalTag {
    NSDictionary *tag = [PWTagsBuilder incrementalTagWithInteger:5];

    XCTAssertEqualObjects(tag[@"operation"], @"increment");
    XCTAssertEqualObjects(tag[@"value"], @5);
}

- (void)testPWTagsBuilderAppendTag {
    NSArray *values = @[@"value1", @"value2"];
    NSDictionary *tag = [PWTagsBuilder appendValuesToListTag:values];

    XCTAssertEqualObjects(tag[@"operation"], @"append");
    XCTAssertEqualObjects(tag[@"value"], values);
}

- (void)testPWTagsBuilderRemoveTag {
    NSArray *values = @[@"value1", @"value2"];
    NSDictionary *tag = [PWTagsBuilder removeValuesFromListTag:values];

    XCTAssertEqualObjects(tag[@"operation"], @"remove");
    XCTAssertEqualObjects(tag[@"value"], values);
}

- (void)testSetDelegateUpdatesManagerBridge {
    id mockDelegate = OCMProtocolMock(@protocol(PWMessagingDelegate));

    [self.pushwoosh setDelegate:mockDelegate];

    XCTAssertEqual([PWManagerBridge shared].delegate, mockDelegate);
}

- (void)testSetDataManagerUpdatesManagerBridge {
    PWDataManager *dataManager = [PWDataManager new];

    [self.pushwoosh setDataManager:dataManager];

    XCTAssertEqual([PWManagerBridge shared].dataManager, dataManager);
}


/// Verifies that the legacy sendBadges does not crash and writes the badge tag like Pushwoosh.configure.sendBadges.
- (void)testSendBadgesWritesBadgeTag {
    PWDataManager *originalDataManager = [PWManagerBridge shared].dataManager;
    id mockDataManager = OCMClassMock([PWDataManager class]);
    OCMExpect([mockDataManager setTags:@{@"badge": @5}]);
    [PWManagerBridge shared].dataManager = mockDataManager;
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [[PWSdkStateProvider sharedInstance] setReady];

    XCTAssertNoThrow([self.pushwoosh sendBadges:5]);

    OCMVerifyAll(mockDataManager);
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [PWManagerBridge shared].dataManager = originalDataManager;
}

/// Verifies that pushwoosh:onMessageReceived: hands the delegate the Pushwoosh instance its type declares.
- (void)testMessageReceivedDelegateGetsPushwooshInstance {
    PWMessagingSenderSpy *spy = [PWMessagingSenderSpy new];
    spy.received = [self expectationWithDescription:@"onMessageReceived"];

    [self deliverToDelegate:spy push:^(NSDictionary *push) {
        [self.pushwoosh.pushNotificationManager handlePushReceived:push autoAcceptAllowed:NO];
    }];

    XCTAssertEqual(spy.receivedSender, self.pushwoosh);
}

/// Verifies that pushwoosh:onMessageOpened: hands the delegate the Pushwoosh instance its type declares.
- (void)testMessageOpenedDelegateGetsPushwooshInstance {
    PWMessagingSenderSpy *spy = [PWMessagingSenderSpy new];
    spy.opened = [self expectationWithDescription:@"onMessageOpened"];

    [self deliverToDelegate:spy push:^(NSDictionary *push) {
        [self.pushwoosh.pushNotificationManager handlePushAccepted:push onStart:NO];
    }];

    XCTAssertEqual(spy.openedSender, self.pushwoosh);
}

- (void)deliverToDelegate:(PWMessagingSenderSpy *)spy push:(void (^)(NSDictionary *push))deliver {
    id originalDelegate = [PWManagerBridge shared].delegate;
    PWDataManager *originalDataManager = [PWManagerBridge shared].dataManager;
    [PWManagerBridge shared].dataManager = OCMClassMock([PWDataManager class]);
    [PWManagerBridge shared].delegate = spy;

    deliver(@{ @"aps": @{ @"alert": @"hi" }, @"p": [NSUUID UUID].UUIDString, @"pw_msg": @"1" });
    [self waitForExpectationsWithTimeout:2 handler:nil];

    [PWManagerBridge shared].delegate = originalDelegate;
    [PWManagerBridge shared].dataManager = originalDataManager;
}

@end

#pragma clang diagnostic pop
