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
#import "PWRequestsCacheManager.h"
#import "PWInAppManager.h"
#import "PWConfig.h"
#import "PWPushNotificationsManager.h"
#import <PushwooshCore/PWDataManager.h>
#import <PushwooshCore/PWManagerBridge.h>

@interface Pushwoosh (TEST)

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
    id mockPWRequestsCacheManager = OCMClassMock([PWRequestsCacheManager class]);
    OCMStub([mockPWRequestsCacheManager sharedInstance]);
    id mockPWInAppManager = OCMClassMock([PWInAppManager class]);
    OCMStub([mockPWInAppManager sharedManager]);
    id mockPWConfig = OCMClassMock([PWConfig class]);
    OCMStub([mockPWConfig config]);
    
    id result = [self.pushwoosh initWithApplicationCode:@"DC533-F5DA4"];
    
    XCTAssert(result);
    XCTAssertEqual([PWPreferences preferences].appCode, @"DC533-F5DA4");
    OCMVerify([mockPWRequestsCacheManager sharedInstance]);
    OCMVerify([mockPWInAppManager sharedManager]);
    OCMVerify([mockPWConfig config]);
    [mockPWRequestsCacheManager stopMocking];
    [mockPWInAppManager stopMocking];
    [mockPWConfig stopMocking];
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

@end
