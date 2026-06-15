#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UserNotifications/UserNotifications.h>

#import "PWNotificationServiceProcessor.h"
#import "PWNetworkModule.h"
#import "PWRequestManager.h"
#import "PWMessageDeliveryRequest.h"

#if TARGET_OS_IOS

@interface PWNotificationServiceProcessor (Test)

@property (nonatomic, strong) PWRequestManager *requestManager;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong, nullable) UNMutableNotificationContent *bestAttemptContent;
@property (nonatomic, assign) BOOL consumed;
@property (nonatomic, copy, nullable) void (^completion)(UNNotificationContent *);

- (NSString *)sanitizedFileNameComponent:(NSString *)name;

@end

@interface PWNotificationServiceProcessorTest : XCTestCase

@property (nonatomic) id mockNetworkModule;

@end

@implementation PWNotificationServiceProcessorTest

- (void)setUp {
    _mockNetworkModule = OCMPartialMock([PWNetworkModule module]);
    OCMStub([_mockNetworkModule inject:OCMOCK_ANY]).andDo(nil);
}

- (void)tearDown {
    [_mockNetworkModule stopMocking];
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

    id mockDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockDefaults alloc]).andReturn(mockDefaults);
    OCMStub([mockDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockDefaults);
    OCMStub([mockDefaults integerForKey:@"badge_count"]).andReturn(2);

    XCTestExpectation *badgeWritten = [self expectationWithDescription:@"badge written"];
    OCMStub([mockDefaults setInteger:4 forKey:@"badge_count"]).andDo(^(NSInvocation *invocation) {
        [badgeWritten fulfill];
    });

    [processor processRequest:request appGroups:@"group.test" completion:^(UNNotificationContent *content) {}];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([mockDefaults setInteger:4 forKey:@"badge_count"]);

    [mockDefaults stopMocking];
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

    id mockDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockDefaults alloc]).andReturn(mockDefaults);
    OCMStub([mockDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockDefaults);
    OCMStub([mockDefaults integerForKey:@"badge_count"]).andReturn(4);

    XCTestExpectation *badgeWritten = [self expectationWithDescription:@"badge written"];
    OCMStub([mockDefaults setInteger:2 forKey:@"badge_count"]).andDo(^(NSInvocation *invocation) {
        [badgeWritten fulfill];
    });

    [processor processRequest:request appGroups:@"group.test" completion:^(UNNotificationContent *content) {}];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([mockDefaults setInteger:2 forKey:@"badge_count"]);

    [mockDefaults stopMocking];
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

    id mockDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockDefaults alloc]).andReturn(mockDefaults);
    OCMStub([mockDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockDefaults);
    OCMStub([mockDefaults integerForKey:@"badge_count"]).andReturn(99);

    XCTestExpectation *badgeWritten = [self expectationWithDescription:@"badge written"];
    OCMStub([mockDefaults setInteger:5 forKey:@"badge_count"]).andDo(^(NSInvocation *invocation) {
        [badgeWritten fulfill];
    });

    [processor processRequest:request appGroups:@"group.test" completion:^(UNNotificationContent *content) {}];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([mockDefaults setInteger:5 forKey:@"badge_count"]);

    [mockDefaults stopMocking];
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

/// Verifies a numeric pw_badge (NSNumber, not a string) is coerced and applied: "10" over a saved count of 3 writes badge_count = 10.
- (void)testNumericBadgeAbsoluteValueIsApplied {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    processor.requestManager = OCMClassMock([PWRequestManager class]);

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{@"pw_badge": @10}, @"pw_msg": @"1"}) content:&mockContent request:&mockRequest];

    id mockDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockDefaults alloc]).andReturn(mockDefaults);
    OCMStub([mockDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockDefaults);
    OCMStub([mockDefaults integerForKey:@"badge_count"]).andReturn(3);

    XCTestExpectation *badgeWritten = [self expectationWithDescription:@"badge written"];
    OCMStub([mockDefaults setInteger:10 forKey:@"badge_count"]).andDo(^(NSInvocation *invocation) {
        [badgeWritten fulfill];
    });

    [processor processRequest:request appGroups:@"group.test" completion:^(UNNotificationContent *content) {}];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([mockDefaults setInteger:10 forKey:@"badge_count"]);

    [mockDefaults stopMocking];
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

    id mockDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockDefaults alloc]).andReturn(mockDefaults);
    OCMStub([mockDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockDefaults);
    OCMStub([mockDefaults integerForKey:@"badge_count"]).andReturn(4);

    XCTestExpectation *badgeWritten = [self expectationWithDescription:@"badge written"];
    OCMStub([mockDefaults setInteger:0 forKey:@"badge_count"]).andDo(^(NSInvocation *invocation) {
        [badgeWritten fulfill];
    });

    [processor processRequest:request appGroups:@"group.test" completion:^(UNNotificationContent *content) {}];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    OCMVerify([mockDefaults setInteger:0 forKey:@"badge_count"]);

    [mockDefaults stopMocking];
    [(id)processor.requestManager stopMocking];
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

@end

#endif
