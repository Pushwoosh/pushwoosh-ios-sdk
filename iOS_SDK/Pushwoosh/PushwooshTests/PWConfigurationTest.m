//
//  PWConfigurationTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 21.02.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import "PWConfig.h"
#import "PWNotificationAppSettings.h"
#import "PWLog.h"

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface PWConfig (TEST)

- (BOOL)getBoolean:(NSString *)key default:(BOOL)defaultValue;

@end

@interface PWConfigurationTest : XCTestCase

@property (nonatomic) PWConfig *config;

@end

@implementation PWConfigurationTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _config = [PWConfig config];
}

- (void)tearDown {
    _config = nil;
    [super tearDown];
}

- (void)testCheckAllParametersWithInitmethod {
    NSString *appId = @"XXXXX-XXXXX";
    NSString *appIdDev = @"App Dev ID";
    NSString *appName = @"APP_NAME";
    NSString *requestUrl = @"pushwoosh.com";
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_APPID"]).andReturn(appId);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_APPID_Dev"]).andReturn(appIdDev);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_APPNAME"]).andReturn(appName);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_SHOW_ALERT"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_SHOULD_SEND_PUSH_STATS_IF_ALERT_DISABLED"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_PURCHASE_TRACKING_ENABLED"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_BASEURL"]).andReturn(requestUrl);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_SDK_SELF_TEST_ENABLE"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_AUTO"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_PURCHASE_TRACKING_ENABLED"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_AUTO_ACCEPT_DEEP_LINK_FOR_SILENT_PUSH"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"PWAutoAcceptDeepLinkForSilentPush"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_ALLOW_SERVER_COMMUNICATION"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_ALLOW_COLLECTING_DEVICE_DATA"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_LOG_LEVEL"]).andReturn(nil);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertEqual(appId, _config.appId);
    XCTAssertEqual(appIdDev, _config.appIdDev);
    XCTAssertEqual(appName, _config.appName);
    XCTAssertTrue(_config.showAlert);
    XCTAssertTrue(_config.sendPushStatIfAlertsDisabled);
    XCTAssertTrue(_config.sendPurchaseTrackingEnabled);
    XCTAssertEqual(_config.alertStyle, PWNotificationAlertStyleBanner);
    XCTAssertEqual(requestUrl, _config.requestUrl);
    XCTAssertTrue(_config.selfTestEnabled);
    XCTAssertTrue(_config.useRuntime);
    XCTAssertTrue(_config.sendPurchaseTrackingEnabled);
    XCTAssertTrue(_config.acceptedDeepLinkForSilentPush);
    XCTAssertTrue(_config.acceptedDeepLinkForSilentPush);
    XCTAssertTrue(_config.allowServerCommunication);
    XCTAssertTrue(_config.allowCollectingDeviceData);
    XCTAssertEqual(_config.logLevel, kLogInfo);
    [mockNSBundle stopMocking];
}

- (void)testCheckAlertTypeBanner {
    NSString *type = @"BANNER";
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_ALERT_TYPE"]).andReturn(type);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertEqual(PWNotificationAlertStyleBanner, _config.alertStyle);
    [mockNSBundle stopMocking];
}

- (void)testCheckAlertTypeAlert {
    NSString *type = @"ALERT";
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_ALERT_TYPE"]).andReturn(type);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertEqual(PWNotificationAlertStyleAlert, _config.alertStyle);
    [mockNSBundle stopMocking];
}

- (void)testCheckAlertTypeNone {
    NSString *type = @"NONE";
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_ALERT_TYPE"]).andReturn(type);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertEqual(PWNotificationAlertStyleNone, _config.alertStyle);
    [mockNSBundle stopMocking];
}

- (void)testAllowCollectingDeviceDataIsFalse {
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_ALLOW_COLLECTING_DEVICE_DATA"]).andReturn(@NO);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertEqual(false, _config.allowCollectingDeviceOsVersion);
    XCTAssertEqual(false, _config.allowCollectingDeviceLocale);
    XCTAssertEqual(false, _config.allowCollectingDeviceModel);
    XCTAssertEqual(false, _config.isCollectingLifecycleEventsAllowed);
    [mockNSBundle stopMocking];
}

- (void)testAllowCollectingDeviceDataIsTrue {
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_ALLOW_COLLECTING_DEVICE_DATA"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_ALLOW_COLLECTING_DEVICE_LOCALE"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_ALLOW_COLLECTING_DEVICE_MODEL"]).andReturn(@YES);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_ALLOW_COLLECTING_EVENTS"]).andReturn(@YES);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertFalse(_config.allowCollectingDeviceOsVersion);
    XCTAssertTrue(_config.allowCollectingDeviceLocale);
    XCTAssertTrue(_config.allowCollectingDeviceModel);
    XCTAssertTrue(_config.isCollectingLifecycleEventsAllowed);
    [mockNSBundle stopMocking];
}

- (void)testLogLevelNone {
    NSString *logLevel = @"NONE";
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_LOG_LEVEL"]).andReturn(logLevel);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertEqual(kLogNone, _config.logLevel);
    [mockNSBundle stopMocking];
}

- (void)testLogLevelError {
    NSString *logLevel = @"ERROR";
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_LOG_LEVEL"]).andReturn(logLevel);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertEqual(kLogError, _config.logLevel);
    [mockNSBundle stopMocking];
}

- (void)testLogLevelWarning {
    NSString *logLevel = @"WARNING";
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_LOG_LEVEL"]).andReturn(logLevel);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertEqual(kLogWarning, _config.logLevel);
    [mockNSBundle stopMocking];
}

- (void)testLogLevelInfo {
    NSString *logLevel = @"INFO";
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_LOG_LEVEL"]).andReturn(logLevel);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertEqual(kLogInfo, _config.logLevel);
    [mockNSBundle stopMocking];
}

- (void)testLogLevelDebug {
    NSString *logLevel = @"DEBUG";
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_LOG_LEVEL"]).andReturn(logLevel);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertEqual(kLogDebug, _config.logLevel);
    [mockNSBundle stopMocking];
}

- (void)testLogLevelVerbose {
    NSString *logLevel = @"VERBOSE";
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"Pushwoosh_LOG_LEVEL"]).andReturn(logLevel);

    _config = [[PWConfig alloc] initWithBundle:[NSBundle mainBundle]];
    
    XCTAssertEqual(kLogVerbose, _config.logLevel);
    [mockNSBundle stopMocking];
}

- (void)testGetBooleanMethodIfDefaultTrueAndValueFromPlistisFalse {
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"SOME_KEY"]).andReturn(@0);

    BOOL returnValue = [_config getBoolean:@"SOME_KEY" default:YES];
    
    XCTAssertFalse(returnValue);
    [mockNSBundle stopMocking];
}

- (void)testGetBooleanMethodWithDefaultValue {
    id mockNSBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockNSBundle objectForInfoDictionaryKey:@"SOME_KEY"]).andDo(nil);

    BOOL returnValue = [_config getBoolean:@"SOME_KEY" default:YES];
    
    XCTAssertTrue(returnValue);
    [mockNSBundle stopMocking];
}

@end
