#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UserNotifications/UserNotifications.h>

#import "PWNotificationServiceProcessor.h"
#import "PWNetworkModule.h"
#import "PWRequestManager.h"
#import "PWMessageDeliveryRequest.h"
#import "PWPreferences.h"
#import "PWConfig.h"
#import "PWSdkStateProvider.h"
#import "PushwooshLog.h"
#import "PWActionButton.h"
#import "PWActionButtonsParser.h"
#import "PWActionButtonsRegistrar.h"
#import "PWServerCommunicationManager.h"
#import "PWDeliveryDelayTestSeams.h"
#import "PWDelayedUploadCapture.h"

#if TARGET_OS_IOS

@interface PWNotificationServiceProcessor (Test)

@property (nonatomic, strong) PWRequestManager *requestManager;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong, nullable) UNMutableNotificationContent *bestAttemptContent;
@property (nonatomic, assign) BOOL consumed;
@property (nonatomic, copy, nullable) void (^completion)(UNNotificationContent *);
@property (nonatomic, strong) PWActionButtonsRegistrar *actionButtonsRegistrar;
@property (nonatomic, copy) NSDate *(^clock)(void);

- (NSString *)sanitizedFileNameComponent:(NSString *)name;

@end

@interface PWRequestManager (ProcessorTest)

- (void)sendRequestInternal:(PWRequest *)request completion:(void (^)(NSError *error))completion;

@end

@interface PWSdkStateProvider (ProcessorTest)

- (void)resetForTesting;

@end

static NSString *const kGatedAppGroup = @"group.com.test.sdk1057";
static NSString *const kGatedAppCode = @"GATED-10570";

@interface PWNotificationServiceProcessorTest : XCTestCase

@property (nonatomic) id mockNetworkModule;
/// Class mock on NSUserDefaults: global while it lives, so tearDown owns its removal.
@property (nonatomic) id mockUserDefaults;
/// Real request manager behind a partial mock: the readiness gate under test is the production one.
@property (nonatomic) id gatedRequestManager;
@property (nonatomic) id mockConfig;
@property (nonatomic) id mockLog;
@property (nonatomic, copy) NSString *savedAppCode;
@property (nonatomic) PWDelayedUploadCapture *upload;
@property (nonatomic) NSURL *uploadContainerURL;

@end

@implementation PWNotificationServiceProcessorTest

- (void)setUp {
    _mockNetworkModule = OCMPartialMock([PWNetworkModule module]);
    OCMStub([_mockNetworkModule inject:OCMOCK_ANY]).andDo(nil);
}

- (void)tearDown {
    [_upload stopMocking];
    _upload = nil;
    if (_uploadContainerURL) {
        [[NSFileManager defaultManager] removeItemAtURL:_uploadContainerURL error:nil];
    }
    [PWDeliveryDelayWindow setUnitRandomProvider:nil];

    // Dropped here rather than in the test body: an assertion failing before
    // stopMocking left NSUserDefaults swapped for the rest of the bundle.
    [_mockUserDefaults stopMocking];
    _mockUserDefaults = nil;
    [_mockNetworkModule stopMocking];

    if (_gatedRequestManager) {
        [_mockLog stopMocking];
        _mockLog = nil;
        [_gatedRequestManager stopMocking];
        _gatedRequestManager = nil;
        [_mockConfig stopMocking];
        _mockConfig = nil;
        [[PWSdkStateProvider sharedInstance] resetForTesting];
        NSUserDefaults *gatedGroup = [[NSUserDefaults alloc] initWithSuiteName:kGatedAppGroup];
        [gatedGroup removeObjectForKey:@"Pushwoosh_EFFECTIVE_APPLICATION"];
        [gatedGroup removeObjectForKey:@"Pushwoosh_APPID"];
        [gatedGroup removeObjectForKey:@"PWReverseProxyURL"];
        [self switchAppCodeTo:_savedAppCode ?: @""];
        [[PWPreferences preferences] updateBaseUrl:[[PWPreferences preferences] defaultBaseUrl]];
    }
}

/// Through an empty code, so neither switch unregisters from the application being left.
- (void)switchAppCodeTo:(NSString *)appCode {
    [PWPreferences preferences].appCode = @"";
    [PWPreferences preferences].appCode = appCode;
}

/// Only the transport is stubbed: everything up to it, the readiness queue included, is real.
- (id)gatedRequestManagerWithAppCode:(NSString *)appCode {
    _savedAppCode = [PWPreferences preferences].appCode;
    [self switchAppCodeTo:appCode];
    [[PWSdkStateProvider sharedInstance] resetForTesting];

    _mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([_mockConfig allowReverseProxy]).andReturn(NO);

    _gatedRequestManager = OCMPartialMock([PWRequestManager new]);
    OCMStub([_gatedRequestManager sendRequestInternal:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });
    return _gatedRequestManager;
}

- (UNNotificationRequest *)requestWithUserInfo:(NSDictionary *)userInfo content:(id *)outContent request:(id *)outRequest {
    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockContent = OCMPartialMock([UNMutableNotificationContent alloc]);
    id mockRequest = OCMPartialMock(request);
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockContent);
    OCMStub([mockContent mutableCopy]).andReturn(mockContent);
    OCMStub([(UNMutableNotificationContent *)mockContent userInfo]).andReturn(userInfo);
    *outContent = mockContent;
    *outRequest = mockRequest;
    return request;
}

/// Verifies a non-Pushwoosh push is delivered through completion unchanged.
- (void)testNonPushwooshMessageDelivers {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{@"alert": @"hi"}}) content:&mockContent request:&mockRequest];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    __block UNNotificationContent *delivered = nil;

    [processor processRequest:request
                    appGroups:nil
                   completion:^(UNNotificationContent *content) { delivered = content; [exp fulfill]; }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqualObjects(delivered, mockContent);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a Pushwoosh push with pw_badge "+2" over a saved count of 2 writes badge_count = 4.
- (void)testBadgePlusSignAddsToSavedCount {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    processor.requestManager = OCMClassMock([PWRequestManager class]);

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{@"pw_badge": @"+2"}, @"pw_msg": @"1"}) content:&mockContent request:&mockRequest];

    _mockUserDefaults = OCMClassMock([NSUserDefaults class]);
    id mockDefaults = _mockUserDefaults;
    OCMStub([mockDefaults alloc]).andReturn(mockDefaults);
    OCMStub([mockDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockDefaults);
    OCMStub([mockDefaults integerForKey:@"badge_count"]).andReturn(2);

    XCTestExpectation *badgeWritten = [self expectationWithDescription:@"badge written"];
    OCMStub([mockDefaults setInteger:4 forKey:@"badge_count"]).andDo(^(NSInvocation *invocation) {
        [badgeWritten fulfill];
    });
    XCTestExpectation *badgeApplied = [self expectationWithDescription:@"badge applied to content"];
    OCMStub([(UNMutableNotificationContent *)mockContent setBadge:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        [badgeApplied fulfill];
    });

    [processor processRequest:request appGroups:@"group.test" completion:^(UNNotificationContent *content) {}];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    dispatch_sync(processor.serialQueue, ^{});
    OCMVerify([mockDefaults setInteger:4 forKey:@"badge_count"]);

    [(id)processor.requestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a Pushwoosh push with pw_badge "-2" over a saved count of 4 writes badge_count = 2.
- (void)testBadgeMinusSignSubtractsFromSavedCount {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    processor.requestManager = OCMClassMock([PWRequestManager class]);

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{@"pw_badge": @"-2"}, @"pw_msg": @"1"}) content:&mockContent request:&mockRequest];

    _mockUserDefaults = OCMClassMock([NSUserDefaults class]);
    id mockDefaults = _mockUserDefaults;
    OCMStub([mockDefaults alloc]).andReturn(mockDefaults);
    OCMStub([mockDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockDefaults);
    OCMStub([mockDefaults integerForKey:@"badge_count"]).andReturn(4);

    XCTestExpectation *badgeWritten = [self expectationWithDescription:@"badge written"];
    OCMStub([mockDefaults setInteger:2 forKey:@"badge_count"]).andDo(^(NSInvocation *invocation) {
        [badgeWritten fulfill];
    });
    XCTestExpectation *badgeApplied = [self expectationWithDescription:@"badge applied to content"];
    OCMStub([(UNMutableNotificationContent *)mockContent setBadge:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        [badgeApplied fulfill];
    });

    [processor processRequest:request appGroups:@"group.test" completion:^(UNNotificationContent *content) {}];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    dispatch_sync(processor.serialQueue, ^{});
    OCMVerify([mockDefaults setInteger:2 forKey:@"badge_count"]);

    [(id)processor.requestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies an absolute pw_badge "5" writes badge_count = 5 regardless of the saved count.
- (void)testBadgeAbsoluteValueOverwritesSavedCount {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    processor.requestManager = OCMClassMock([PWRequestManager class]);

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{@"pw_badge": @"5"}, @"pw_msg": @"1"}) content:&mockContent request:&mockRequest];

    _mockUserDefaults = OCMClassMock([NSUserDefaults class]);
    id mockDefaults = _mockUserDefaults;
    OCMStub([mockDefaults alloc]).andReturn(mockDefaults);
    OCMStub([mockDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockDefaults);
    OCMStub([mockDefaults integerForKey:@"badge_count"]).andReturn(99);

    XCTestExpectation *badgeWritten = [self expectationWithDescription:@"badge written"];
    OCMStub([mockDefaults setInteger:5 forKey:@"badge_count"]).andDo(^(NSInvocation *invocation) {
        [badgeWritten fulfill];
    });
    XCTestExpectation *badgeApplied = [self expectationWithDescription:@"badge applied to content"];
    OCMStub([(UNMutableNotificationContent *)mockContent setBadge:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        [badgeApplied fulfill];
    });

    [processor processRequest:request appGroups:@"group.test" completion:^(UNNotificationContent *content) {}];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    dispatch_sync(processor.serialQueue, ^{});
    OCMVerify([mockDefaults setInteger:5 forKey:@"badge_count"]);

    [(id)processor.requestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a Pushwoosh push triggers a PWMessageDeliveryRequest send.
- (void)testDeliveryEventIsSentForPushwooshMessage {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    processor.requestManager = mockRequestManager;

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}) content:&mockContent request:&mockRequest];

    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {}];

    OCMVerify([mockRequestManager sendRequest:[OCMArg isKindOfClass:[PWMessageDeliveryRequest class]] completion:OCMOCK_ANY]);

    [mockRequestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies the delivery event loads reverse proxy settings from the resolved App Group passed to the processor, so the NSE reads the same suite the host app wrote to instead of PWConfig.
- (void)testDeliveryEventLoadsReverseProxyFromResolvedAppGroup {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    processor.requestManager = mockRequestManager;

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}) content:&mockContent request:&mockRequest];

    [processor processRequest:request appGroups:@"group.com.test.delivery" completion:^(UNNotificationContent *content) {}];

    OCMVerify([mockRequestManager loadReverseProxyFromAppGroups:@"group.com.test.delivery"]);

    [mockRequestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// SDK-882: Verifies the delivery path reloads the active application from the resolved App Group, so a reused extension process follows the application the host app switched to.
- (void)testDeliveryEventReloadsActiveApplicationFromAppGroup {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    processor.requestManager = mockRequestManager;

    id mockPreferences = OCMPartialMock([PWPreferences preferences]);

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}) content:&mockContent request:&mockRequest];

    [processor processRequest:request appGroups:@"group.com.test.delivery" completion:^(UNNotificationContent *content) {}];

    OCMVerify([mockPreferences loadActiveApplicationFromAppGroups:@"group.com.test.delivery"]);

    [mockPreferences stopMocking];
    [mockRequestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a second processRequest: on the same processor instance still invokes the contentHandler (regression: the consumed flag must be reset per push so a reused processor delivers the next push).
- (void)testSecondProcessRequestStillDelivers {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });
    processor.requestManager = mockRequestManager;

    for (NSInteger i = 0; i < 2; i++) {
        id mockContent; id mockRequest;
        UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}) content:&mockContent request:&mockRequest];

        XCTestExpectation *exp = [self expectationWithDescription:[NSString stringWithFormat:@"delivered %ld", (long)i]];
        __block UNNotificationContent *delivered = nil;
        [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
            delivered = content;
            [exp fulfill];
        }];

        [self waitForExpectationsWithTimeout:2 handler:nil];
        XCTAssertEqualObjects(delivered, mockContent);

        [mockContent stopMocking];
        [mockRequest stopMocking];
    }

    [(id)processor.requestManager stopMocking];
}

/// Verifies arming once then calling process twice sends exactly one delivery request (started guard prevents double delivery).
- (void)testProcessCalledTwiceSendsOneDeliveryRequest {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });
    processor.requestManager = mockRequestManager;

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}) content:&mockContent request:&mockRequest];

    [processor armWithRequest:request appGroups:nil completion:^(UNNotificationContent *content) {}];
    [processor process];
    [processor process];

    dispatch_sync(processor.serialQueue, ^{});
    OCMVerify(times(1), [mockRequestManager sendRequest:[OCMArg isKindOfClass:[PWMessageDeliveryRequest class]] completion:OCMOCK_ANY]);

    [mockRequestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

#pragma mark - Receive time

- (PWNotificationServiceProcessor *)processorCapturingDeliveryRequests:(NSMutableArray<PWMessageDeliveryRequest *> *)captured {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWMessageDeliveryRequest *sent = nil;
        [invocation getArgument:&sent atIndex:2];
        [captured addObject:sent];
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });
    processor.requestManager = mockRequestManager;
    return processor;
}

/// Verifies the delivery event sent at once carries the moment the push was received as receivedAt (RFC 3339 UTC, whole seconds).
- (void)testImmediateDeliveryEventCarriesReceiveTime {
    NSMutableArray *captured = [NSMutableArray new];
    PWNotificationServiceProcessor *processor = [self processorCapturingDeliveryRequests:captured];
    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"} content:&mockContent request:&mockRequest];

    NSInteger before = (NSInteger)[NSDate date].timeIntervalSince1970;
    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {}];
    NSInteger after = (NSInteger)[NSDate date].timeIntervalSince1970;
    dispatch_sync(processor.serialQueue, ^{});

    XCTAssertEqual(captured.count, 1u);
    NSDictionary *dict = [captured.firstObject requestDictionary];
    NSDate *stamped = [[NSISO8601DateFormatter new] dateFromString:dict[@"receivedAt"]];
    XCTAssertNotNil(stamped);
    XCTAssertGreaterThanOrEqual(stamped.timeIntervalSince1970, before);
    XCTAssertLessThanOrEqual(stamped.timeIntervalSince1970, after);
    XCTAssertNil(dict[@"timestampUTC"]);

    [(id)processor.requestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies the stamp is taken when the processor is armed: a send that starts later does not move it.
- (void)testReceiveTimeIsTakenWhenArmedNotWhenProcessed {
    NSMutableArray *captured = [NSMutableArray new];
    PWNotificationServiceProcessor *processor = [self processorCapturingDeliveryRequests:captured];
    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"} content:&mockContent request:&mockRequest];

    __block NSTimeInterval now = 1795000000;
    processor.clock = ^NSDate *{ return [NSDate dateWithTimeIntervalSince1970:now]; };
    [processor armWithRequest:request appGroups:nil completion:^(UNNotificationContent *content) {}];
    now += 180;
    [processor process];
    dispatch_sync(processor.serialQueue, ^{});

    XCTAssertEqual(captured.count, 1u);
    XCTAssertEqualObjects([captured.firstObject requestDictionary][@"receivedAt"], @"2026-11-18T11:06:40Z");
    XCTAssertNil([captured.firstObject requestDictionary][@"timestampUTC"]);

    [(id)processor.requestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a processor re-armed for a second push stamps that push's own receive time, not the first one's.
- (void)testReArmedProcessorStampsTheNewPush {
    NSMutableArray *captured = [NSMutableArray new];
    PWNotificationServiceProcessor *processor = [self processorCapturingDeliveryRequests:captured];
    id mockContentA; id mockRequestA; id mockContentB; id mockRequestB;
    UNNotificationRequest *requestA = [self requestWithUserInfo:@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash-a"} content:&mockContentA request:&mockRequestA];
    UNNotificationRequest *requestB = [self requestWithUserInfo:@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash-b"} content:&mockContentB request:&mockRequestB];

    __block NSTimeInterval now = 1795000000;
    processor.clock = ^NSDate *{ return [NSDate dateWithTimeIntervalSince1970:now]; };
    [processor armWithRequest:requestA appGroups:nil completion:^(UNNotificationContent *content) {}];
    now += 60;
    [processor armWithRequest:requestB appGroups:nil completion:^(UNNotificationContent *content) {}];
    [processor process];
    dispatch_sync(processor.serialQueue, ^{});

    XCTAssertEqual(captured.count, 1u);
    NSDictionary *dict = [captured.firstObject requestDictionary];
    XCTAssertEqualObjects(dict[@"hash"], @"hash-b");
    XCTAssertEqualObjects(dict[@"receivedAt"], @"2026-11-18T11:07:40Z");
    XCTAssertNil(dict[@"timestampUTC"]);

    [(id)processor.requestManager stopMocking];
    [mockContentA stopMocking];
    [mockRequestA stopMocking];
    [mockContentB stopMocking];
    [mockRequestB stopMocking];
}

/// Verifies a numeric pw_badge (NSNumber, not a string) is coerced and applied: "10" over a saved count of 3 writes badge_count = 10.
- (void)testNumericBadgeAbsoluteValueIsApplied {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    processor.requestManager = OCMClassMock([PWRequestManager class]);

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{@"pw_badge": @10}, @"pw_msg": @"1"}) content:&mockContent request:&mockRequest];

    _mockUserDefaults = OCMClassMock([NSUserDefaults class]);
    id mockDefaults = _mockUserDefaults;
    OCMStub([mockDefaults alloc]).andReturn(mockDefaults);
    OCMStub([mockDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockDefaults);
    OCMStub([mockDefaults integerForKey:@"badge_count"]).andReturn(3);

    XCTestExpectation *badgeWritten = [self expectationWithDescription:@"badge written"];
    OCMStub([mockDefaults setInteger:10 forKey:@"badge_count"]).andDo(^(NSInvocation *invocation) {
        [badgeWritten fulfill];
    });
    XCTestExpectation *badgeApplied = [self expectationWithDescription:@"badge applied to content"];
    OCMStub([(UNMutableNotificationContent *)mockContent setBadge:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        [badgeApplied fulfill];
    });

    [processor processRequest:request appGroups:@"group.test" completion:^(UNNotificationContent *content) {}];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    dispatch_sync(processor.serialQueue, ^{});
    OCMVerify([mockDefaults setInteger:10 forKey:@"badge_count"]);

    [(id)processor.requestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies expireWithFallback delivers the original immutable content when bestAttemptContent is nil, so the contentHandler still fires exactly once.
- (void)testExpireFallbackDeliversOriginalContentWhenBestAttemptNil {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];

    UNNotificationRequest *request = [UNNotificationRequest alloc];
    id mockContent = OCMPartialMock([UNNotificationContent alloc]);
    id mockRequest = OCMPartialMock(request);
    OCMStub([(UNNotificationRequest *)mockRequest content]).andReturn(mockContent);
    OCMStub([mockContent mutableCopy]).andReturn(nil);
    OCMStub([(UNNotificationContent *)mockContent userInfo]).andReturn(@{@"aps": @{@"alert": @"hi"}});

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    __block NSInteger callCount = 0;
    __block UNNotificationContent *delivered = nil;
    [processor armWithRequest:request
                    appGroups:nil
                   completion:^(UNNotificationContent *content) { callCount++; delivered = content; [exp fulfill]; }];

    XCTAssertNil(processor.bestAttemptContent);
    [processor expireWithFallback];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(callCount, 1);
    XCTAssertEqualObjects(delivered, mockContent);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a nil request manager does not hang: the delivery step balances its dispatch group leave so the contentHandler still fires.
- (void)testNilRequestManagerStillDelivers {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    processor.requestManager = nil;

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}) content:&mockContent request:&mockRequest];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    __block UNNotificationContent *delivered = nil;
    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        delivered = content;
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqualObjects(delivered, mockContent);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies expireWithFallback delivers the best-attempt content through completion exactly once.
- (void)testExpireFallbackDeliversBestAttemptOnce {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = @"best attempt";
    processor.bestAttemptContent = content;

    __block NSInteger callCount = 0;
    __block UNNotificationContent *delivered = nil;
    XCTestExpectation *exp = [self expectationWithDescription:@"expired"];
    processor.completion = ^(UNNotificationContent *c) { callCount++; delivered = c; [exp fulfill]; };

    [processor expireWithFallback];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(callCount, 1);
    XCTAssertEqualObjects(delivered.title, @"best attempt");
}

/// Verifies two concurrent expireWithFallback calls deliver exactly once (consumed flag serialized on the queue).
- (void)testExpireRacingItselfDeliversOnce {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    processor.bestAttemptContent = content;

    __block NSInteger callCount = 0;
    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    exp.assertForOverFulfill = NO;
    processor.completion = ^(UNNotificationContent *c) { callCount++; [exp fulfill]; };

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [processor expireWithFallback];
    });
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [processor expireWithFallback];
    });

    [self waitForExpectationsWithTimeout:2 handler:nil];
    dispatch_sync(processor.serialQueue, ^{});
    XCTAssertEqual(callCount, 1);
}

/// Verifies a Pushwoosh push with a valid https attachment URL downloads, moves and attaches the media to the content, then still fires the contentHandler.
- (void)testAttachmentDownloadSuccessAddsAttachmentToContent {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });
    processor.requestManager = mockRequestManager;

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"attachment": @"https://example.com/img.jpg"}) content:&mockContent request:&mockRequest];
    OCMStub([(UNMutableNotificationContent *)mockContent attachments]).andReturn(@[]);

    id mockResponse = OCMClassMock([NSURLResponse class]);
    OCMStub([mockResponse suggestedFilename]).andReturn(@"img.jpg");

    id mockTask = OCMClassMock([NSURLSessionDownloadTask class]);
    NSURL *fakeLocation = [NSURL fileURLWithPath:@"/tmp/pw-download-source"];
    OCMStub([mockTask resume]).andDo(^(NSInvocation *invocation) {});

    id mockSession = OCMClassMock([NSURLSession class]);
    OCMStub([mockSession sharedSession]).andReturn(mockSession);
    OCMStub([mockSession downloadTaskWithURL:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^handler)(NSURL *, NSURLResponse *, NSError *) = nil;
        [invocation getArgument:&handler atIndex:3];
        if (handler) {
            handler(fakeLocation, mockResponse, nil);
        }
    }).andReturn(mockTask);

    id mockFileManager = OCMPartialMock([NSFileManager defaultManager]);
    OCMStub([mockFileManager containerURLForSecurityApplicationGroupIdentifier:OCMOCK_ANY]).andReturn(nil);
    OCMStub([mockFileManager moveItemAtPath:OCMOCK_ANY toPath:OCMOCK_ANY error:[OCMArg anyObjectRef]]).andReturn(YES);

    id mockAttachment = OCMClassMock([UNNotificationAttachment class]);
    OCMStub([mockAttachment attachmentWithIdentifier:OCMOCK_ANY URL:OCMOCK_ANY options:OCMOCK_ANY error:[OCMArg anyObjectRef]]).andReturn(mockAttachment);

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    dispatch_sync(processor.serialQueue, ^{});
    OCMVerify([(UNMutableNotificationContent *)mockContent setAttachments:[OCMArg checkWithBlock:^BOOL(NSArray *attachments) {
        return [attachments containsObject:mockAttachment];
    }]]);

    [mockAttachment stopMocking];
    [mockFileManager stopMocking];
    [mockSession stopMocking];
    [mockTask stopMocking];
    [mockResponse stopMocking];
    [mockRequestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a download failure (non-nil error) is tolerated: no attachment is added and the contentHandler still fires so the extension does not hang.
- (void)testAttachmentDownloadErrorIsToleratedAndStillDelivers {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });
    processor.requestManager = mockRequestManager;

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"attachment": @"https://example.com/img.jpg"}) content:&mockContent request:&mockRequest];
    OCMStub([(UNMutableNotificationContent *)mockContent attachments]).andReturn(@[]);

    id mockTask = OCMClassMock([NSURLSessionDownloadTask class]);
    OCMStub([mockTask resume]).andDo(^(NSInvocation *invocation) {});

    NSError *downloadError = [NSError errorWithDomain:@"test" code:-1 userInfo:nil];
    id mockSession = OCMClassMock([NSURLSession class]);
    OCMStub([mockSession sharedSession]).andReturn(mockSession);
    OCMStub([mockSession downloadTaskWithURL:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^handler)(NSURL *, NSURLResponse *, NSError *) = nil;
        [invocation getArgument:&handler atIndex:3];
        if (handler) {
            handler(nil, nil, downloadError);
        }
    }).andReturn(mockTask);

    [[(id)mockContent reject] setAttachments:OCMOCK_ANY];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    dispatch_sync(processor.serialQueue, ^{});

    [mockSession stopMocking];
    [mockTask stopMocking];
    [mockRequestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a non-string attachment value short-circuits without starting a download and the contentHandler still fires.
- (void)testNonStringAttachmentKeyStillDelivers {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });
    processor.requestManager = mockRequestManager;

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"attachment": @5}) content:&mockContent request:&mockRequest];

    id mockSession = OCMClassMock([NSURLSession class]);
    OCMStub([mockSession sharedSession]).andReturn(mockSession);
    [[mockSession reject] downloadTaskWithURL:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    dispatch_sync(processor.serialQueue, ^{});

    [mockSession stopMocking];
    [mockRequestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies sanitizedFileNameComponent: strips directory traversal, collapses multi-segment paths to the last component and preserves a plain filename.
- (void)testSanitizedFileNameStripsPathTraversal {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];

    NSString *traversal = [processor sanitizedFileNameComponent:@"../../evil.jpg"];
    XCTAssertEqual([traversal rangeOfString:@"/"].location, NSNotFound);
    XCTAssertEqual([traversal rangeOfString:@".."].location, NSNotFound);

    XCTAssertEqualObjects([processor sanitizedFileNameComponent:@"img.png"], @"img.png");

    NSString *multi = [processor sanitizedFileNameComponent:@"a/b/c.gif"];
    XCTAssertEqual([multi rangeOfString:@"/"].location, NSNotFound);
    XCTAssertEqualObjects(multi, @"c.gif");
}

/// Verifies pw_badge "-100" over a saved count of 4 clamps to badge_count = 0 at the processor level.
- (void)testBadgeMinusUnderflowClampsToZeroAtProcessorLevel {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    processor.requestManager = OCMClassMock([PWRequestManager class]);

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{@"pw_badge": @"-100"}, @"pw_msg": @"1"}) content:&mockContent request:&mockRequest];

    _mockUserDefaults = OCMClassMock([NSUserDefaults class]);
    id mockDefaults = _mockUserDefaults;
    OCMStub([mockDefaults alloc]).andReturn(mockDefaults);
    OCMStub([mockDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockDefaults);
    OCMStub([mockDefaults integerForKey:@"badge_count"]).andReturn(4);

    XCTestExpectation *badgeWritten = [self expectationWithDescription:@"badge written"];
    OCMStub([mockDefaults setInteger:0 forKey:@"badge_count"]).andDo(^(NSInvocation *invocation) {
        [badgeWritten fulfill];
    });
    XCTestExpectation *badgeApplied = [self expectationWithDescription:@"badge applied to content"];
    OCMStub([(UNMutableNotificationContent *)mockContent setBadge:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        [badgeApplied fulfill];
    });

    [processor processRequest:request appGroups:@"group.test" completion:^(UNNotificationContent *content) {}];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    dispatch_sync(processor.serialQueue, ^{});
    OCMVerify([mockDefaults setInteger:0 forKey:@"badge_count"]);

    [(id)processor.requestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// SDK-1057: Verifies an extension with no app code delivers the notification at once, sends no delivery event and names the missing configuration.
- (void)testNoAppCodeDeliversWithoutWaitingAndSkipsDeliveryEvent {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id requestManager = [self gatedRequestManagerWithAppCode:@""];
    processor.requestManager = requestManager;
    OCMReject([requestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]);

    _mockLog = OCMClassMock([PushwooshLog class]);
    OCMExpect([_mockLog pushwooshLog:PW_LL_WARN className:OCMOCK_ANY message:[OCMArg checkWithBlock:^BOOL(NSString *message) {
        return [message hasPrefix:@"messageDeliveryEvent skipped"] && [message containsString:@"Pushwoosh_APPID"] && [message containsString:@"PW_APP_GROUPS_NAME"];
    }]]);

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}) content:&mockContent request:&mockRequest];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    __block UNNotificationContent *delivered = nil;
    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        delivered = content;
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqualObjects(delivered, mockContent);
    XCTAssertFalse([[PWSdkStateProvider sharedInstance] isReady]);
    OCMVerifyAll(_mockLog);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// SDK-1057: Verifies an app code that reaches the extension through the App Group after the request manager started still sends the delivery event.
- (void)testAppCodeLoadedFromAppGroupAfterStartSendsDeliveryEvent {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id requestManager = [self gatedRequestManagerWithAppCode:@""];
    processor.requestManager = requestManager;

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kGatedAppGroup];
    [shared setObject:@{ @"appCode": kGatedAppCode, @"baseUrl": @"https://region-b.example.com/json/1.3/" } forKey:@"Pushwoosh_EFFECTIVE_APPLICATION"];
    [shared synchronize];

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}) content:&mockContent request:&mockRequest];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [processor processRequest:request appGroups:kGatedAppGroup completion:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqualObjects([PWPreferences preferences].appCode, kGatedAppCode);
    OCMVerify([requestManager sendRequestInternal:[OCMArg isKindOfClass:[PWMessageDeliveryRequest class]] completion:OCMOCK_ANY]);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// SDK-1057: Verifies an app code the app stores with plain setAppCode after the extension started still sends the delivery event.
- (void)testAppCodeSharedByPlainSetAppCodeAfterStartSendsDeliveryEvent {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id requestManager = [self gatedRequestManagerWithAppCode:@""];
    processor.requestManager = requestManager;

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kGatedAppGroup];
    [shared setObject:kGatedAppCode forKey:@"Pushwoosh_APPID"];
    [shared synchronize];

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}) content:&mockContent request:&mockRequest];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [processor processRequest:request appGroups:kGatedAppGroup completion:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqualObjects([PWPreferences preferences].appCode, kGatedAppCode);
    OCMVerify([requestManager sendRequestInternal:[OCMArg isKindOfClass:[PWMessageDeliveryRequest class]] completion:OCMOCK_ANY]);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies an extension that knows the app code sends the delivery event and then delivers the notification.
- (void)testConfiguredAppCodeSendsDeliveryEvent {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id requestManager = [self gatedRequestManagerWithAppCode:kGatedAppCode];
    processor.requestManager = requestManager;

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}) content:&mockContent request:&mockRequest];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([requestManager sendRequestInternal:[OCMArg isKindOfClass:[PWMessageDeliveryRequest class]] completion:OCMOCK_ANY]);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

#pragma mark - Delivery delay

/// The background session is a mock: the test sees what the system would be handed and nothing is sent.
- (void)captureDelayedUploadsWithContainer:(BOOL)hasContainer {
    if (hasContainer) {
        _uploadContainerURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
        [[NSFileManager defaultManager] createDirectoryAtURL:_uploadContainerURL withIntermediateDirectories:YES attributes:nil error:nil];
    }

    _upload = [PWDelayedUploadCapture new];
    OCMStub([_upload.uploaderMock containerURLForAppGroup:kGatedAppGroup]).andReturn(_uploadContainerURL);
}

- (UNNotificationContent *)processUserInfo:(NSDictionary *)userInfo
                                 processor:(PWNotificationServiceProcessor *)processor
                                 appGroups:(NSString *)appGroups {
    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:userInfo content:&mockContent request:&mockRequest];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    __block UNNotificationContent *delivered = nil;
    [processor processRequest:request appGroups:appGroups completion:^(UNNotificationContent *content) {
        delivered = content;
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    [mockContent stopMocking];
    [mockRequest stopMocking];
    return delivered;
}

/// Verifies a push with a window and an App Group hands the delivery event to the system with the request the REST transport would send, starting within the window, and is shown without the event being sent.
- (void)testDeliveryDelayWithAppGroupHandsEventToSystemAndDeliversAtOnce {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id requestManager = [self gatedRequestManagerWithAppCode:kGatedAppCode];
    processor.requestManager = requestManager;
    OCMReject([requestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]);
    [self captureDelayedUploadsWithContainer:YES];
    [PWDeliveryDelayWindow setUnitRandomProvider:^double { return 1.0; }];

    NSDate *before = [NSDate date];
    UNNotificationContent *delivered = [self processUserInfo:@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash-1", @"pw_delivery_delay": @"60"}
                                                   processor:processor
                                                   appGroups:kGatedAppGroup];
    NSDate *after = [NSDate date];

    XCTAssertNotNil(delivered);
    XCTAssertTrue([_upload.request.URL.absoluteString hasSuffix:@"/messageDeliveryEvent"]);
    XCTAssertEqualObjects(_upload.request.HTTPMethod, @"POST");
    XCTAssertEqualObjects([_upload.request valueForHTTPHeaderField:@"Content-Type"], @"application/json; charset=utf-8");
    XCTAssertTrue([[_upload.request valueForHTTPHeaderField:@"Authorization"] hasPrefix:@"Token "]);

    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:_upload.body options:0 error:nil][@"request"];
    XCTAssertEqualObjects(body[@"hash"], @"hash-1");
    XCTAssertEqualObjects(body[@"application"], kGatedAppCode);

    XCTAssertGreaterThanOrEqual([_upload.earliestBeginDate timeIntervalSinceDate:before], 60);
    XCTAssertLessThanOrEqual([_upload.earliestBeginDate timeIntervalSinceDate:after], 60);
}

/// Verifies a delayed delivery event carries the receive time in its body while the system is asked to send it a window later.
- (void)testDelayedDeliveryBodyCarriesReceiveTime {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id requestManager = [self gatedRequestManagerWithAppCode:kGatedAppCode];
    processor.requestManager = requestManager;
    [self captureDelayedUploadsWithContainer:YES];
    [PWDeliveryDelayWindow setUnitRandomProvider:^double { return 1.0; }];

    NSInteger before = (NSInteger)[NSDate date].timeIntervalSince1970;
    NSDate *beforeDate = [NSDate date];
    [self processUserInfo:@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash-1", @"pw_delivery_delay": @"60"}
                processor:processor
                appGroups:kGatedAppGroup];
    NSInteger after = (NSInteger)[NSDate date].timeIntervalSince1970;

    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:_upload.body options:0 error:nil][@"request"];
    NSDate *stamped = [[NSISO8601DateFormatter new] dateFromString:body[@"receivedAt"]];
    XCTAssertNotNil(stamped);
    XCTAssertGreaterThanOrEqual(stamped.timeIntervalSince1970, before);
    XCTAssertLessThanOrEqual(stamped.timeIntervalSince1970, after);
    XCTAssertNil(body[@"timestampUTC"]);
    XCTAssertGreaterThanOrEqual([_upload.earliestBeginDate timeIntervalSinceDate:beforeDate], 59);

    [requestManager stopMocking];
}

/// Verifies a push with a window but no App Group container sends the delivery event at once, as without the key.
- (void)testDeliveryDelayWithoutAppGroupSendsAtOnce {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id requestManager = [self gatedRequestManagerWithAppCode:kGatedAppCode];
    processor.requestManager = requestManager;
    [self captureDelayedUploadsWithContainer:NO];
    OCMReject([_upload.sessionMock uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY]);

    [self processUserInfo:@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash-1", @"pw_delivery_delay": @"60"}
                processor:processor
                appGroups:nil];

    OCMVerify([requestManager sendRequestInternal:[OCMArg isKindOfClass:[PWMessageDeliveryRequest class]] completion:OCMOCK_ANY]);
}

/// Verifies an invalid window value sends the delivery event at once, as without the key.
- (void)testInvalidDeliveryDelaySendsAtOnce {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id requestManager = [self gatedRequestManagerWithAppCode:kGatedAppCode];
    processor.requestManager = requestManager;
    [self captureDelayedUploadsWithContainer:YES];
    OCMReject([_upload.sessionMock uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY]);

    [self processUserInfo:@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash-1", @"pw_delivery_delay": @"abc"}
                processor:processor
                appGroups:kGatedAppGroup];

    OCMVerify([requestManager sendRequestInternal:[OCMArg isKindOfClass:[PWMessageDeliveryRequest class]] completion:OCMOCK_ANY]);
}

/// Verifies a push without the key is shown only after the delivery event is answered, as before the window existed.
- (void)testWithoutDeliveryDelayShowingWaitsForDeliveryEvent {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id requestManager = OCMClassMock([PWRequestManager class]);
    __block void (^heldCompletion)(NSError *) = nil;
    OCMStub([requestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        heldCompletion = [completion copy];
    });
    processor.requestManager = requestManager;
    [self captureDelayedUploadsWithContainer:YES];
    OCMReject([_upload.sessionMock uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY]);

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash-1"}) content:&mockContent request:&mockRequest];
    __block BOOL delivered = NO;
    [processor processRequest:request appGroups:kGatedAppGroup completion:^(UNNotificationContent *content) {
        delivered = YES;
    }];

    XCTAssertTrue([self spinUntil:^BOOL { return heldCompletion != nil; } timeout:2]);
    XCTAssertFalse([self spinUntil:^BOOL { return delivered; } timeout:0.3]);
    heldCompletion(nil);
    XCTAssertTrue([self spinUntil:^BOOL { return delivered; } timeout:2]);

    [requestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a window does not schedule the delivery event while server communication is disabled, and the event is refused as before.
- (void)testDeliveryDelayWithServerCommunicationDisabledSchedulesNothing {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id requestManager = [self gatedRequestManagerWithAppCode:kGatedAppCode];
    processor.requestManager = requestManager;
    [self captureDelayedUploadsWithContainer:YES];
    OCMReject([_upload.sessionMock uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY]);
    id communication = OCMPartialMock([PWServerCommunicationManager sharedInstance]);
    OCMStub([communication isServerCommunicationAllowed]).andReturn(NO);

    _mockLog = OCMClassMock([PushwooshLog class]);
    OCMExpect([_mockLog pushwooshLog:PW_LL_WARN className:OCMOCK_ANY message:[OCMArg checkWithBlock:^BOOL(NSString *message) {
        return [message hasPrefix:@"messageDeliveryEvent not delivered"] && [message containsString:@"Communication with Pushwoosh is disabled"];
    }]]);

    UNNotificationContent *delivered = [self processUserInfo:@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash-1", @"pw_delivery_delay": @"60"}
                                                   processor:processor
                                                   appGroups:kGatedAppGroup];

    XCTAssertNotNil(delivered);
    OCMVerifyAll(_mockLog);
    [communication stopMocking];
}

/// Verifies a window does not schedule the delivery event when the extension has no app code, and the missing configuration is named as before.
/// The App Group shares a reverse proxy, so a request could be built and only the app code check keeps it from the system.
- (void)testDeliveryDelayWithoutAppCodeSchedulesNothing {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id requestManager = [self gatedRequestManagerWithAppCode:@""];
    processor.requestManager = requestManager;
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kGatedAppGroup];
    [shared setObject:@"https://proxy.example.com/" forKey:@"PWReverseProxyURL"];
    [shared synchronize];
    OCMReject([requestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]);
    [self captureDelayedUploadsWithContainer:YES];
    OCMReject([_upload.sessionMock uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY]);

    _mockLog = OCMClassMock([PushwooshLog class]);
    OCMExpect([_mockLog pushwooshLog:PW_LL_WARN className:OCMOCK_ANY message:[OCMArg checkWithBlock:^BOOL(NSString *message) {
        return [message hasPrefix:@"messageDeliveryEvent skipped"] && [message containsString:@"no Pushwoosh app code"];
    }]]);

    UNNotificationContent *delivered = [self processUserInfo:@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash-1", @"pw_delivery_delay": @"60"}
                                                   processor:processor
                                                   appGroups:kGatedAppGroup];

    XCTAssertNotNil(delivered);
    OCMVerifyAll(_mockLog);
}

#pragma mark - Action buttons

/// A registrar wired to a fake notification center, so the tests can see what iOS would be given.
- (PWActionButtonsRegistrar *)trackingRegistrarRecordingInto:(NSMutableArray<NSSet<UNNotificationCategory *> *> *)sets {
    id centerMock = OCMClassMock([UNUserNotificationCenter class]);
    OCMStub([centerMock getNotificationCategoriesWithCompletionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^handler)(NSSet<UNNotificationCategory *> *) = nil;
        [invocation getArgument:&handler atIndex:2];
        handler([NSSet set]);
    });
    OCMStub([centerMock setNotificationCategories:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSSet<UNNotificationCategory *> *categories = nil;
        [invocation getArgument:&categories atIndex:2];
        [sets addObject:[categories copy]];
    });
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.pushwoosh.tests.nse.actionbuttons"];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:@"com.pushwoosh.tests.nse.actionbuttons"];
    return [[PWActionButtonsRegistrar alloc] initWithNotificationCenter:centerMock defaults:defaults];
}

/// Spins the run loop until the predicate holds or the wait runs out; the registrar answers from its
/// own queue, so nothing it does is observable on the line after the call.
- (BOOL)spinUntil:(BOOL (^)(void))predicate timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!predicate() && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
    }
    return predicate();
}

- (NSString *)buttonsJSON {
    return @"[{\"id\":\"open_app\",\"label\":\"Open\",\"action\":\"open\"},"
            "{\"id\":\"site\",\"label\":\"Website\",\"action\":\"url\",\"url\":\"https://www.pushwoosh.com\"}]";
}

/// Verifies a push with pw_buttons is delivered with the category identifier of its own buttons, and
/// that the category was registered with iOS before the content handler ran.
- (void)testPushWithActionButtonsIsDeliveredWithItsCategoryRegistered {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });
    processor.requestManager = mockRequestManager;

    NSMutableArray<NSSet<UNNotificationCategory *> *> *registeredSets = [NSMutableArray array];
    processor.actionButtonsRegistrar = [self trackingRegistrarRecordingInto:registeredSets];

    NSDictionary *userInfo = @{ @"aps" : @{ @"alert" : @"hi" }, @"pw_msg" : @"1", @"p" : @"hash", @"pw_buttons" : [self buttonsJSON] };
    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:userInfo content:&mockContent request:&mockRequest];

    NSArray<PWActionButton *> *buttons = [PWActionButtonsParser buttonsFromUserInfo:userInfo];
    NSString *expectedCategory = [PWActionButtonsRegistrar categoryIdentifierForButtons:buttons];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];

    OCMVerify([mockContent setCategoryIdentifier:expectedCategory]);
    XCTAssertEqual(registeredSets.count, 1);
    NSMutableSet *registeredIds = [NSMutableSet set];
    for (UNNotificationCategory *category in registeredSets.firstObject) {
        [registeredIds addObject:category.identifier];
    }
    XCTAssertTrue([registeredIds containsObject:expectedCategory]);

    [mockRequestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a push whose buttons are there replaces whatever aps.category named, so the buttons the
/// marketer put in this push are the ones the user sees.
- (void)testActionButtonsOverrideTheIncomingCategory {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });
    processor.requestManager = mockRequestManager;
    processor.actionButtonsRegistrar = [self trackingRegistrarRecordingInto:[NSMutableArray array]];

    NSDictionary *userInfo = @{ @"aps" : @{ @"alert" : @"hi", @"category" : @"ios_category_custom" },
                                @"pw_msg" : @"1", @"p" : @"hash", @"pw_buttons" : [self buttonsJSON] };
    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:userInfo content:&mockContent request:&mockRequest];

    NSString *expectedCategory = [PWActionButtonsRegistrar categoryIdentifierForButtons:[PWActionButtonsParser buttonsFromUserInfo:userInfo]];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([mockContent setCategoryIdentifier:expectedCategory]);

    [mockRequestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a push without pw_buttons keeps the category it arrived with and registers nothing, so an
/// application on the Control Panel category path is untouched.
- (void)testPushWithoutActionButtonsLeavesTheCategoryAlone {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });
    processor.requestManager = mockRequestManager;

    NSMutableArray<NSSet<UNNotificationCategory *> *> *registeredSets = [NSMutableArray array];
    processor.actionButtonsRegistrar = [self trackingRegistrarRecordingInto:registeredSets];

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{ @"aps" : @{ @"alert" : @"hi", @"category" : @"9301" }, @"pw_msg" : @"1", @"p" : @"hash" })
                                                      content:&mockContent
                                                      request:&mockRequest];
    OCMReject([mockContent setCategoryIdentifier:OCMOCK_ANY]);

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(registeredSets.count, 0);

    [mockRequestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a pw_buttons value nobody can parse costs the push its buttons and nothing else: it is
/// still delivered, with no category of ours and no registration.
- (void)testBrokenActionButtonsStillDeliverThePush {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });
    processor.requestManager = mockRequestManager;

    NSMutableArray<NSSet<UNNotificationCategory *> *> *registeredSets = [NSMutableArray array];
    processor.actionButtonsRegistrar = [self trackingRegistrarRecordingInto:registeredSets];

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{ @"aps" : @{ @"alert" : @"hi" }, @"pw_msg" : @"1", @"p" : @"hash", @"pw_buttons" : @"[{\"id\":" })
                                                      content:&mockContent
                                                      request:&mockRequest];
    OCMReject([mockContent setCategoryIdentifier:OCMOCK_ANY]);

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    __block UNNotificationContent *delivered = nil;
    [processor processRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        delivered = content;
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqualObjects(delivered, mockContent);
    XCTAssertEqual(registeredSets.count, 0);

    [mockRequestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies the timeout fallback registers the stamped category with iOS before it delivers, so a push
/// that never reached process still expands with its buttons instead of naming a category nobody has.
- (void)testExpireFallbackRegistersTheButtonsCategoryBeforeDelivering {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];

    NSMutableArray<NSSet<UNNotificationCategory *> *> *registeredSets = [NSMutableArray array];
    processor.actionButtonsRegistrar = [self trackingRegistrarRecordingInto:registeredSets];

    NSDictionary *userInfo = @{ @"aps" : @{ @"alert" : @"hi" }, @"pw_msg" : @"1", @"p" : @"hash", @"pw_buttons" : [self buttonsJSON] };
    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:userInfo content:&mockContent request:&mockRequest];
    NSString *expectedCategory = [PWActionButtonsRegistrar categoryIdentifierForButtons:[PWActionButtonsParser buttonsFromUserInfo:userInfo]];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    __block NSUInteger registeredWhenDelivered = NSNotFound;
    [processor armWithRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        registeredWhenDelivered = registeredSets.count;
        [exp fulfill];
    }];

    OCMVerify([mockContent setCategoryIdentifier:expectedCategory]);

    [processor expireWithFallback];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqual(registeredWhenDelivered, 1);

    NSMutableSet *registeredIds = [NSMutableSet set];
    for (UNNotificationCategory *category in registeredSets.lastObject) {
        [registeredIds addObject:category.identifier];
    }
    XCTAssertTrue([registeredIds containsObject:expectedCategory]);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies the timeout fallback delivers on its own deadline while another push is still holding the
/// process-wide category gate, so a registration that cannot proceed never costs a push its delivery.
- (void)testExpireFallbackDeliversWhileAnotherPushHoldsTheCategoryGate {
    NSString *suite = @"com.pushwoosh.tests.nse.gatehold";
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:suite];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];

    NSLock *lock = [NSLock new];
    __block void (^parked)(NSSet<UNNotificationCategory *> *) = nil;
    __block BOOL parksTheNextRead = YES;

    id centerMock = OCMClassMock([UNUserNotificationCenter class]);
    OCMStub([centerMock getNotificationCategoriesWithCompletionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^handler)(NSSet<UNNotificationCategory *> *) = nil;
        [invocation getArgument:&handler atIndex:2];

        [lock lock];
        BOOL park = parksTheNextRead;
        if (park) {
            parksTheNextRead = NO;
            parked = [handler copy];
        }
        [lock unlock];

        if (!park) {
            handler([NSSet set]);
        }
    });
    __block NSUInteger setCount = 0;
    OCMStub([centerMock setNotificationCategories:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        [lock lock];
        setCount++;
        [lock unlock];
    });

    NSArray<PWActionButton *> *heldButtons = [PWActionButtonsParser buttonsFromUserInfo:@{ @"pw_msg" : @"1", @"pw_buttons" : [self buttonsJSON] }];
    PWActionButtonsRegistrar *holder = [[PWActionButtonsRegistrar alloc] initWithNotificationCenter:centerMock defaults:defaults];
    [holder registerCategoryForButtons:heldButtons completion:^{}];

    XCTAssertTrue([self spinUntil:^BOOL {
        [lock lock];
        BOOL took = parked != nil;
        [lock unlock];
        return took;
    } timeout:2], @"the holding registrar never took the gate");

    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    processor.actionButtonsRegistrar = [[PWActionButtonsRegistrar alloc] initWithNotificationCenter:centerMock defaults:defaults];

    NSDictionary *userInfo = @{ @"aps" : @{ @"alert" : @"hi" }, @"pw_msg" : @"1", @"p" : @"hash", @"pw_buttons" : [self buttonsJSON] };
    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:userInfo content:&mockContent request:&mockRequest];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [processor armWithRequest:request appGroups:nil completion:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [processor expireWithFallback];

    /// Between the fallback's 100 ms deadline and the gate's 500 ms timeout, so only the deadline can
    /// satisfy this: a pass cannot come from the gate giving up.
    [self waitForExpectationsWithTimeout:0.35 handler:nil];

    [lock lock];
    void (^resume)(NSSet<UNNotificationCategory *> *) = parked;
    parked = nil;
    [lock unlock];

    if (resume) {
        resume([NSSet set]);
    }

    XCTAssertTrue([self spinUntil:^BOOL {
        [lock lock];
        BOOL bothWrote = setCount >= 2;
        [lock unlock];
        return bothWrote;
    } timeout:2], @"a registration was still in flight; stopping the mock would leak the gate");

    [centerMock stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:suite];
}

@end

#endif
