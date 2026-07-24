
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWInAppMessagesManager.h"
#import "PWResource.h"
#import "PWModuleResolution.h"
#import "PWTriggerInAppActionRequest.h"
#import "PWManagerBridge.h"
#import "PWRichMediaManager.h"
#import "PWRichMedia.h"
#import "PWRichMedia+Internal.h"
#import "PWPreferences.h"

@interface PWInAppMessagesManager (Test)

- (void)presentRichMediaFromPush:(NSDictionary *)userInfo;
- (void)richMediaTypeWith:(id)richMedia resource:(PWResource *)resource;

@end

@interface PWFakeInAppHandler : NSObject <PWInAppHandler>

@property (nonatomic, strong) NSDictionary *receivedConfig;
@property (nonatomic, copy) void (^receivedOnShown)(void);
@property (nonatomic, copy) void (^receivedOnClicked)(void);
@property (nonatomic, copy) void (^receivedOnClosed)(void);
@property (nonatomic, copy) void (^onHandle)(void);

@end

@implementation PWFakeInAppHandler

- (void)handleInAppConfig:(NSDictionary *)config {
    [self handleInAppConfig:config onShown:nil];
}

- (void)handleInAppConfig:(NSDictionary *)config onShown:(void (^)(void))onShown {
    [self handleInAppConfig:config onShown:onShown onClicked:nil onClosed:nil];
}

- (void)handleInAppConfig:(NSDictionary *)config onShown:(void (^)(void))onShown onClicked:(void (^)(void))onClicked onClosed:(void (^)(void))onClosed {
    self.receivedConfig = config;
    self.receivedOnShown = onShown;
    self.receivedOnClicked = onClicked;
    self.receivedOnClosed = onClosed;
    if (self.onHandle) {
        self.onHandle();
    }
}

@end

@interface PWNativeInAppRouteTest : XCTestCase

@property (nonatomic, strong) PWInAppMessagesManager *manager;
@property (nonatomic, strong) PWResource *resource;
@property (nonatomic, strong) PWFakeInAppHandler *handler;
@property (nonatomic, strong) PWRichMediaManager *prevRichMediaManager;
@property (nonatomic, strong) PWInAppMessagesManager *prevInAppMessagesManager;
@property (nonatomic, copy) NSString *prevLanguage;

@end

@implementation PWNativeInAppRouteTest

- (void)setUp {
    [super setUp];
    self.manager = [PWInAppMessagesManager new];
    self.resource = [[PWResource alloc] initWithDictionary:@{ @"code": @"r-TEST-ROUTE",
                                                              @"url": @"https://example.com/test.zip",
                                                              @"updated": @1 }];
    self.handler = [PWFakeInAppHandler new];
    [PushwooshModuleRegistry registerHandler:self.handler forIdentifier:PWModuleIdentifierInApp];

    self.prevRichMediaManager = [PWManagerBridge shared].richMediaManager;
    self.prevInAppMessagesManager = [PWManagerBridge shared].inAppMessagesManager;
    [PWManagerBridge shared].richMediaManager = [PWRichMediaManager sharedManager];
    [PWManagerBridge shared].inAppMessagesManager = self.manager;

    self.prevLanguage = [[PWPreferences preferences].language copy];
}

- (void)tearDown {
    [PushwooshModuleRegistry registerHandler:nil forIdentifier:PWModuleIdentifierInApp];
    [PWManagerBridge shared].richMediaManager = self.prevRichMediaManager;
    [PWManagerBridge shared].inAppMessagesManager = self.prevInAppMessagesManager;
    [[NSFileManager defaultManager] removeItemAtPath:[self.resource localPath] error:nil];
    [PWPreferences preferences].language = self.prevLanguage;
    self.manager = nil;
    self.resource = nil;
    self.handler = nil;
    [super tearDown];
}

- (void)writeNativeConfig:(NSString *)json {
    [[NSFileManager defaultManager] createDirectoryAtPath:[self.resource localPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    [json writeToFile:[self.resource nativeConfigUrl]
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:nil];
}

- (void)writePushwooshConfig:(NSString *)json {
    [[NSFileManager defaultManager] createDirectoryAtPath:[self.resource localPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    [json writeToFile:[self.resource configUrl]
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:nil];
}

/// Verifies that a valid native-config.json is parsed and delivered to the registered handler together with a show hook.
- (void)testRouteDeliversConfigAndShowHookToHandler {
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"Hi\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:@"hash-123"];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"displayType"], @"modal");
    XCTAssertNotNil(self.handler.receivedOnShown);
}

/// Verifies that invoking the show hook sends the same show statistics request as regular in-apps, carrying the postEvent message hash.
- (void)testOnShownSendsShowStatisticsWithMessageHash {
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"Hi\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };
    [self.manager routeNativeInAppForResource:self.resource messageHash:@"hash-456"];
    [self waitForExpectations:@[handled] timeout:3.0];

    PWTriggerInAppActionRequest *request = [PWTriggerInAppActionRequest new];
    id requestClassMock = OCMClassMock([PWTriggerInAppActionRequest class]);
    OCMStub([requestClassMock new]).andReturn(request);

    self.handler.receivedOnShown();

    XCTAssertEqualObjects(request.messageHash, @"hash-456");
    XCTAssertEqualObjects(request.richMediaCode, @"TEST-ROUTE");
    XCTAssertEqualObjects(request.inAppCode, @"");
    [requestClassMock stopMocking];
}

/// Verifies that the click hook sends /richMediaAction with action type 1 and the rich media code mapping.
- (void)testOnClickedSendsRichMediaActionClick {
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"Hi\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };
    [self.manager routeNativeInAppForResource:self.resource messageHash:@"hash-789"];
    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertNotNil(self.handler.receivedOnClicked);

    id partialManager = OCMPartialMock(self.manager);
    OCMExpect([partialManager richMediaAction:@"" richMediaCode:@"r-TEST-ROUTE" actionType:@1 actionAttributes:[OCMArg isNil] messageHash:@"hash-789" completion:[OCMArg isNil]]);

    self.handler.receivedOnClicked();

    OCMVerifyAll(partialManager);
    [partialManager stopMocking];
}

/// Verifies that the close hook sends /richMediaAction with action type 4 and the same code mapping and message hash.
- (void)testOnClosedSendsRichMediaActionClose {
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"Hi\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };
    [self.manager routeNativeInAppForResource:self.resource messageHash:@"hash-790"];
    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertNotNil(self.handler.receivedOnClosed);

    id partialManager = OCMPartialMock(self.manager);
    OCMExpect([partialManager richMediaAction:@"" richMediaCode:@"r-TEST-ROUTE" actionType:@4 actionAttributes:[OCMArg isNil] messageHash:@"hash-790" completion:[OCMArg isNil]]);

    self.handler.receivedOnClosed();

    OCMVerifyAll(partialManager);
    [partialManager stopMocking];
}

/// Verifies that a non rich media resource maps to inapp_code instead of rich_media_code in click statistics.
- (void)testOnClickedForInAppResourceMapsInAppCode {
    PWResource *inAppResource = [[PWResource alloc] initWithDictionary:@{ @"code": @"INAPP-CODE",
                                                                          @"url": @"https://example.com/inapp.zip",
                                                                          @"updated": @1 }];
    [[NSFileManager defaultManager] createDirectoryAtPath:[inAppResource localPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    [@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"Hi\"}}}" writeToFile:[inAppResource nativeConfigUrl]
                                                                              atomically:YES
                                                                                encoding:NSUTF8StringEncoding
                                                                                   error:nil];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };
    [self.manager routeNativeInAppForResource:inAppResource messageHash:nil];
    [self waitForExpectations:@[handled] timeout:3.0];

    id partialManager = OCMPartialMock(self.manager);
    OCMExpect([partialManager richMediaAction:@"INAPP-CODE" richMediaCode:@"" actionType:@1 actionAttributes:[OCMArg isNil] messageHash:[OCMArg isNil] completion:[OCMArg isNil]]);

    self.handler.receivedOnClicked();

    OCMVerifyAll(partialManager);
    [partialManager stopMocking];
    [[NSFileManager defaultManager] removeItemAtPath:[inAppResource localPath] error:nil];
}

/// Verifies that a ZIP-delivered in-app without inAppId falls back to the resource code as its id, giving dedup and frequency caps a stable key.
- (void)testRouteInjectsResourceCodeAsInAppIdFallback {
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"Hi\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"inAppId"], @"r-TEST-ROUTE");
}

/// Verifies that an author-provided inAppId is preserved and not overwritten by the resource code.
- (void)testRouteKeepsExplicitInAppId {
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"inAppId\":\"author-id\",\"modal\":{\"title\":{\"text\":\"Hi\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"inAppId"], @"author-id");
}

/// Verifies that placeholder strings in native-config.json are localized from pushwoosh.json before reaching the handler.
- (void)testRouteLocalizesConfigStrings {
    [self writePushwooshConfig:@"{\"default_language\":\"en\",\"localization\":{\"en\":{\"greeting\":\"Hello\"}}}"];
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"{{greeting|text|Hi}}\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"modal"][@"title"][@"text"], @"Hello");
}

/// Verifies real-world rich-media localization: human-readable keys with spaces, a color-typed placeholder, nested title.text, and language fallback to default_language all resolve from pushwoosh.json.
- (void)testRouteLocalizesRealWorldPushwooshJSON {
    [self writePushwooshConfig:@"{\"default_language\":\"en\",\"localization\":{\"en\":{\"Header text\":\"Your Favorite Content!\",\"Header text color\":\"14234c\"}}}"];
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"background\":\"{{Header text color|color|000000}}\",\"title\":{\"text\":\"{{Header text|text|Welcome}}\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"modal"][@"title"][@"text"], @"Your Favorite Content!");
    XCTAssertEqualObjects(self.handler.receivedConfig[@"modal"][@"background"], @"14234c");
}

/// Verifies that a multi-language pushwoosh.json (ar/en/fr) resolves the active English section (spaced keys, a color value and a unicode payload) without the extra sections interfering.
- (void)testRouteLocalizesMultiLanguagePushwooshJSON {
    [PWPreferences preferences].language = @"en";
    [self writePushwooshConfig:@"{\"default_language\":\"en\",\"localization\":{"
     "\"ar\":{\"Header text\":\"AR value\",\"Header text color\":\"aa0000\"},"
     "\"en\":{\"Header text\":\"EN value \U0001F3AE\",\"Header text color\":\"14234c\"},"
     "\"fr\":{\"Header text\":\"FR value\",\"Header text color\":\"00aa00\"}}}"];
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"background\":\"{{Header text color|color|000000}}\",\"title\":{\"text\":\"{{Header text|text|Welcome}}\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"modal"][@"title"][@"text"], @"EN value \U0001F3AE");
    XCTAssertEqualObjects(self.handler.receivedConfig[@"modal"][@"background"], @"14234c");
}

/// Verifies that when the device language is absent from localization, the default_language section is used as the fallback.
- (void)testRouteLocalizationFallsBackToDefaultLanguage {
    [PWPreferences preferences].language = @"en";
    [self writePushwooshConfig:@"{\"default_language\":\"fr\",\"localization\":{"
     "\"ar\":{\"Header text\":\"AR value\"},"
     "\"fr\":{\"Header text\":\"FR value\"}}}"];
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"{{Header text|text|Welcome}}\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"modal"][@"title"][@"text"], @"FR value");
}

/// Verifies that a currency modifier (dollar) formats a localized numeric value with thousands grouping before reaching the handler.
- (void)testRouteFormatsCurrencyModifier {
    [self writePushwooshConfig:@"{\"default_language\":\"en\",\"localization\":{\"en\":{\"Price\":\"1000\"}}}"];
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"{{Price|dollar|0}}\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"modal"][@"title"][@"text"], @"$1,000");
}

/// Verifies that a date modifier formats a localized unix timestamp (seconds, GMT) before reaching the handler.
- (void)testRouteFormatsDateModifier {
    [self writePushwooshConfig:@"{\"default_language\":\"en\",\"localization\":{\"en\":{\"When\":\"0\"}}}"];
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"{{When|m-d-y|}}\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"modal"][@"title"][@"text"], @"01-01-70");
}

/// Verifies a typed modifier still formats when the editor emits the empty-default form {{key|type|}} (the trailing pipe must not leak into the modifier).
- (void)testRouteFormatsCurrencyModifierWithEditorEmptyDefault {
    [self writePushwooshConfig:@"{\"default_language\":\"en\",\"localization\":{\"en\":{\"Price\":\"1000\"}}}"];
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"{{Price|dollar|}}\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"modal"][@"title"][@"text"], @"$1,000");
}

/// Verifies that a single-brace {tag|type|default} placeholder nested inside a localized string collapses to its default (empty tag map) instead of leaking raw braces.
- (void)testRouteCollapsesSingleBracePlaceholderToDefault {
    [self writePushwooshConfig:@"{\"default_language\":\"en\",\"localization\":{\"en\":{\"Line\":\"Code {promo|text|SAVE10}\"}}}"];
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"{{Line|text|x}}\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"modal"][@"title"][@"text"], @"Code SAVE10");
}

/// Verifies that a corrupted native-config.json is skipped and never reaches the handler.
- (void)testBrokenNativeConfigDoesNotReachHandler {
    [self writeNativeConfig:@"{not-a-json"];
    XCTestExpectation *notHandled = [self expectationWithDescription:@"handler must not be called"];
    notHandled.inverted = YES;
    self.handler.onHandle = ^{ [notHandled fulfill]; };

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    [self waitForExpectations:@[notHandled] timeout:1.0];
}

/// Verifies that a native-config delivered inside a rich-media ZIP opened through a push is detected in the push funnel and reaches the handler with the resource code injected as inAppId.
- (void)testPresentRichMediaFromPushRoutesNativeConfig {
    PWResource *pushResource = [[PWResource alloc] initWithDictionary:@{ @"code": @"r-PUSH-ROUTE",
                                                                         @"url": @"https://example.com/PUSH-ROUTE.zip",
                                                                         @"updated": @0 }];
    [[NSFileManager defaultManager] createDirectoryAtPath:[pushResource localPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    [@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"Hi\"}}}" writeToFile:[pushResource nativeConfigUrl]
                                                                             atomically:YES
                                                                               encoding:NSUTF8StringEncoding
                                                                                  error:nil];

    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config via push"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    NSDictionary *userInfo = @{ @"p": @"push-hash-1",
                                @"rm": @{ @"url": @"https://example.com/PUSH-ROUTE.zip",
                                          @"ts": @"0",
                                          @"tags": @{} } };
    [self.manager presentRichMediaFromPush:userInfo];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"displayType"], @"modal");
    XCTAssertEqualObjects(self.handler.receivedConfig[@"inAppId"], @"r-PUSH-ROUTE");
    XCTAssertNotNil(self.handler.receivedOnShown);

    [[NSFileManager defaultManager] removeItemAtPath:[pushResource localPath] error:nil];
}

/// Verifies that the push message hash (userInfo["p"]) is the hash used for the show statistics of a native in-app opened through a push.
- (void)testPresentRichMediaFromPushUsesPushMessageHashForStatistics {
    PWResource *pushResource = [[PWResource alloc] initWithDictionary:@{ @"code": @"r-PUSH-HASH",
                                                                         @"url": @"https://example.com/PUSH-HASH.zip",
                                                                         @"updated": @0 }];
    [[NSFileManager defaultManager] createDirectoryAtPath:[pushResource localPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    [@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"Hi\"}}}" writeToFile:[pushResource nativeConfigUrl]
                                                                             atomically:YES
                                                                               encoding:NSUTF8StringEncoding
                                                                                  error:nil];

    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config via push"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    NSDictionary *userInfo = @{ @"p": @"push-hash-2",
                                @"rm": @{ @"url": @"https://example.com/PUSH-HASH.zip",
                                          @"ts": @"0",
                                          @"tags": @{} } };
    [self.manager presentRichMediaFromPush:userInfo];
    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertNotNil(self.handler.receivedOnShown);

    PWTriggerInAppActionRequest *request = [PWTriggerInAppActionRequest new];
    id requestClassMock = OCMClassMock([PWTriggerInAppActionRequest class]);
    OCMStub([requestClassMock new]).andReturn(request);

    self.handler.receivedOnShown();

    XCTAssertEqualObjects(request.messageHash, @"push-hash-2");
    XCTAssertEqualObjects(request.richMediaCode, @"PUSH-HASH");
    XCTAssertEqualObjects(request.inAppCode, @"");
    [requestClassMock stopMocking];

    [[NSFileManager defaultManager] removeItemAtPath:[pushResource localPath] error:nil];
}

/// Verifies that a regular rich-media push (no native-config.json) is not routed to the native handler and stays on the existing HTML presentation path.
- (void)testPresentRichMediaFromPushWithoutNativeConfigStaysOnHtmlPath {
    PWResource *pushResource = [[PWResource alloc] initWithDictionary:@{ @"code": @"r-PUSH-HTML",
                                                                         @"url": @"https://example.com/PUSH-HTML.zip",
                                                                         @"updated": @0 }];
    NSString *dir = [pushResource localPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    [@"<html><head></head><body>hi</body></html>" writeToFile:[dir stringByAppendingPathComponent:@"index.html"]
                                                    atomically:YES
                                                      encoding:NSUTF8StringEncoding
                                                         error:nil];

    XCTestExpectation *nativeNotHandled = [self expectationWithDescription:@"native handler must not be called"];
    nativeNotHandled.inverted = YES;
    self.handler.onHandle = ^{ [nativeNotHandled fulfill]; };

    XCTestExpectation *gateChecked = [self expectationWithDescription:@"html resource reaches the shouldPresent gate"];
    id prevDelegate = [PWRichMediaManager sharedManager].delegate;
    id delegateMock = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    [OCMStub([delegateMock richMediaManager:[OCMArg any] shouldPresentRichMedia:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) { [gateChecked fulfill]; })
        andReturnValue:OCMOCK_VALUE((BOOL){NO})];
    [PWRichMediaManager sharedManager].delegate = delegateMock;

    NSDictionary *userInfo = @{ @"p": @"push-hash-3",
                                @"rm": @{ @"url": @"https://example.com/PUSH-HTML.zip",
                                          @"ts": @"0",
                                          @"tags": @{} } };
    [self.manager presentRichMediaFromPush:userInfo];

    [self waitForExpectations:@[gateChecked, nativeNotHandled] timeout:2.0];

    [PWRichMediaManager sharedManager].delegate = prevDelegate;
    [[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
}

/// Verifies the single rich-media funnel: presentRichMedia: with a native-config resource routes to the native handler (covering every channel that converges on presentRichMedia: — postEvent, push, silent, inbox, manual), passes the message hash to show analytics, and returns BEFORE the shouldPresentRichMedia: gate so no HTML/modal presentation is triggered.
- (void)testPresentRichMediaFunnelRoutesNativeConfig {
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"Hi\"}}}"];
    XCTestExpectation *handled = [self expectationWithDescription:@"handler received config via funnel"];
    self.handler.onHandle = ^{ [handled fulfill]; };

    id prevDelegate = [PWRichMediaManager sharedManager].delegate;
    id delegateMock = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMReject([delegateMock richMediaManager:[OCMArg any] shouldPresentRichMedia:[OCMArg any]]);
    [PWRichMediaManager sharedManager].delegate = delegateMock;

    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:self.resource pushPayload:@{ @"p": @"funnel-hash" }];
    [[PWRichMediaManager sharedManager] presentRichMedia:richMedia];

    [self waitForExpectations:@[handled] timeout:3.0];
    XCTAssertEqualObjects(self.handler.receivedConfig[@"displayType"], @"modal");
    XCTAssertEqualObjects(self.handler.receivedConfig[@"inAppId"], @"r-TEST-ROUTE");

    PWTriggerInAppActionRequest *request = [PWTriggerInAppActionRequest new];
    id requestClassMock = OCMClassMock([PWTriggerInAppActionRequest class]);
    OCMStub([requestClassMock new]).andReturn(request);
    self.handler.receivedOnShown();
    XCTAssertEqualObjects(request.messageHash, @"funnel-hash");
    [requestClassMock stopMocking];

    OCMVerifyAll(delegateMock);
    [PWRichMediaManager sharedManager].delegate = prevDelegate;
}

/// Verifies that a corrupted native-config.json reports a presenting failure to the rich-media delegate (parity with Android onError on read failure) and never reaches the handler.
- (void)testBrokenNativeConfigNotifiesPresentingFailure {
    [self writeNativeConfig:@"{not-a-json"];
    id prevDelegate = [PWRichMediaManager sharedManager].delegate;
    id delegateMock = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    XCTestExpectation *failed = [self expectationWithDescription:@"presenting failure reported"];
    OCMStub([delegateMock richMediaManager:[OCMArg any] presentingDidFailForRichMedia:[OCMArg any] withError:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) { [failed fulfill]; });
    [PWRichMediaManager sharedManager].delegate = delegateMock;

    [self.manager routeNativeInAppForResource:self.resource messageHash:@"err-hash"];

    [self waitForExpectations:@[failed] timeout:3.0];
    XCTAssertNil(self.handler.receivedConfig);
    [PWRichMediaManager sharedManager].delegate = prevDelegate;
}

/// Verifies that routing without a registered PushwooshInApp handler is a safe no-op.
- (void)testMissingHandlerDoesNotCrash {
    [PushwooshModuleRegistry registerHandler:nil forIdentifier:PWModuleIdentifierInApp];
    [self writeNativeConfig:@"{\"displayType\":\"modal\",\"modal\":{\"title\":{\"text\":\"Hi\"}}}"];
    XCTestExpectation *drained = [self expectationWithDescription:@"async route drained"];

    [self.manager routeNativeInAppForResource:self.resource messageHash:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [drained fulfill];
    });
    [self waitForExpectations:@[drained] timeout:3.0];
}

@end
