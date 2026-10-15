#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UserNotifications/UserNotifications.h>

#import "PushwooshNotificationServiceExtension.h"
#import "PWNotificationServiceProcessor.h"
#import "PWNetworkModule.h"
#import "PWRequestManager.h"
#import "PWMessageDeliveryRequest.h"
#import "PWActionButton.h"
#import "PWActionButtonsParser.h"
#import "PWActionButtonsRegistrar.h"

#if TARGET_OS_IOS

@interface PushwooshNotificationServiceExtension (Test)
@property (nonatomic, strong) NSMutableArray<PWNotificationServiceProcessor *> *processors;
@end

@interface PWNotificationServiceProcessor (DelegationTest)
@property (nonatomic, strong) PWRequestManager *requestManager;
@property (nonatomic, strong, nullable) UNMutableNotificationContent *bestAttemptContent;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, copy, nullable) void (^completion)(UNNotificationContent *);
@property (nonatomic, strong) PWActionButtonsRegistrar *actionButtonsRegistrar;
@end

@interface PWHookServiceExtension : PushwooshNotificationServiceExtension
@end
@implementation PWHookServiceExtension
- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request
                   withContentHandler:(void (^)(UNNotificationContent *))contentHandler {
    [super didReceiveNotificationRequest:request withContentHandler:^(UNNotificationContent *content) {
        if ([content isKindOfClass:[UNMutableNotificationContent class]]) {
            ((UNMutableNotificationContent *)content).title = @"hooked";
        }
        contentHandler(content);
    }];
}
@end

@interface PWAppGroupServiceExtension : PushwooshNotificationServiceExtension
@end
@implementation PWAppGroupServiceExtension
- (NSString *)pushwooshAppGroupsName {
    return @"group.test.override";
}
@end

@interface PWManualPrepareServiceExtension : PushwooshNotificationServiceExtension
@property (nonatomic, copy) void (^capturedCompletion)(void);
@end
@implementation PWManualPrepareServiceExtension
- (void)pushwooshPrepareForRequest:(UNNotificationRequest *)request
                        completion:(void (^)(void))completion {
    self.capturedCompletion = completion;
}
@end

@interface PushwooshNotificationServiceExtensionTest : XCTestCase
@property (nonatomic) id mockNetworkModule;
@property (nonatomic) id stubbedRequestManager;
/// Class mock on NSUserDefaults: global while it lives, so tearDown owns its removal.
@property (nonatomic) id mockUserDefaults;
/// Backs every per-call processor's actionButtonsRegistrar, so tests never reach the real
/// UNUserNotificationCenter, which does not call back inside the unit test host.
@property (nonatomic) id mockNotificationCenter;
@property (nonatomic, strong) PWActionButtonsRegistrar *fakeActionButtonsRegistrar;
@end

@implementation PushwooshNotificationServiceExtensionTest

- (void)setUp {
    _stubbedRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([_stubbedRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(nil);
        }
    });

    _mockNotificationCenter = OCMClassMock([UNUserNotificationCenter class]);
    OCMStub([_mockNotificationCenter getNotificationCategoriesWithCompletionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void (^handler)(NSSet<UNNotificationCategory *> *) = nil;
        [invocation getArgument:&handler atIndex:2];
        handler([NSSet set]);
    });
    OCMStub([_mockNotificationCenter setNotificationCategories:OCMOCK_ANY]).andDo(nil);
    NSString *suiteName = @"com.pushwoosh.tests.nse.extension.actionbuttons";
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:suiteName];
    _fakeActionButtonsRegistrar = [[PWActionButtonsRegistrar alloc] initWithNotificationCenter:_mockNotificationCenter
                                                                                       defaults:[[NSUserDefaults alloc] initWithSuiteName:suiteName]];

    _mockNetworkModule = OCMPartialMock([PWNetworkModule module]);
    OCMStub([_mockNetworkModule inject:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWNotificationServiceProcessor *processor = nil;
        [invocation getArgument:&processor atIndex:2];
        processor.requestManager = self.stubbedRequestManager;
        if ([processor isKindOfClass:[PWNotificationServiceProcessor class]]) {
            processor.actionButtonsRegistrar = self.fakeActionButtonsRegistrar;
        }
    });
}

- (void)tearDown {
    // Dropped here rather than in the test body: an assertion failing before
    // stopMocking left NSUserDefaults swapped for the rest of the bundle.
    [_mockUserDefaults stopMocking];
    _mockUserDefaults = nil;
    [_mockNetworkModule stopMocking];
    [_stubbedRequestManager stopMocking];
    [_mockNotificationCenter stopMocking];
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

/// Verifies serviceExtensionTimeWillExpire delivers the best-attempt content even when the prepare hook is still running and processing has not started.
- (void)testTimeoutFallbackDeliversBestAttemptContentDuringPrepare {
    PWManualPrepareServiceExtension *extension = [PWManualPrepareServiceExtension new];

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{@"alert": @"hi"}}) content:&mockContent request:&mockRequest];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    __block UNNotificationContent *delivered = nil;
    [extension didReceiveNotificationRequest:request withContentHandler:^(UNNotificationContent *content) {
        delivered = content;
        [exp fulfill];
    }];

    XCTAssertNotNil(extension.processors.lastObject.bestAttemptContent);
    [extension serviceExtensionTimeWillExpire];

    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertEqualObjects(delivered, mockContent);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies serviceExtensionTimeWillExpire delivers every in-flight processor, not only the latest, when two pushes overlap on a reused extension instance.
- (void)testTimeoutFallbackDeliversAllOverlappingProcessors {
    PWManualPrepareServiceExtension *extension = [PWManualPrepareServiceExtension new];

    id mockContentA; id mockRequestA;
    UNNotificationRequest *requestA = [self requestWithUserInfo:(@{@"aps": @{@"alert": @"a"}}) content:&mockContentA request:&mockRequestA];
    id mockContentB; id mockRequestB;
    UNNotificationRequest *requestB = [self requestWithUserInfo:(@{@"aps": @{@"alert": @"b"}}) content:&mockContentB request:&mockRequestB];

    XCTestExpectation *expA = [self expectationWithDescription:@"delivered A"];
    XCTestExpectation *expB = [self expectationWithDescription:@"delivered B"];
    __block UNNotificationContent *deliveredA = nil;
    __block UNNotificationContent *deliveredB = nil;

    [extension didReceiveNotificationRequest:requestA withContentHandler:^(UNNotificationContent *content) {
        deliveredA = content;
        [expA fulfill];
    }];
    [extension didReceiveNotificationRequest:requestB withContentHandler:^(UNNotificationContent *content) {
        deliveredB = content;
        [expB fulfill];
    }];

    XCTAssertEqual(extension.processors.count, 2);
    [extension serviceExtensionTimeWillExpire];

    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertEqualObjects(deliveredA, mockContentA);
    XCTAssertEqualObjects(deliveredB, mockContentB);

    [mockContentA stopMocking];
    [mockRequestA stopMocking];
    [mockContentB stopMocking];
    [mockRequestB stopMocking];
}

/// Verifies a subclass that overrides didReceive and wraps the content handler can mutate the delivered content.
- (void)testContentHookMutationIsDelivered {
    PWHookServiceExtension *extension = [PWHookServiceExtension new];

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{@"alert": @"hi"}}) content:&mockContent request:&mockRequest];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    __block UNNotificationContent *delivered = nil;
    [extension didReceiveNotificationRequest:request withContentHandler:^(UNNotificationContent *content) {
        delivered = content;
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
    OCMVerify([mockContent setTitle:@"hooked"]);
    XCTAssertEqualObjects(delivered, mockContent);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies processing is deferred until the pushwooshPrepareForRequest:completion: hook calls its completion block.
- (void)testPrepareHookGatesProcessing {
    PWManualPrepareServiceExtension *extension = [PWManualPrepareServiceExtension new];

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{}, @"pw_msg": @"1", @"p": @"hash"}) content:&mockContent request:&mockRequest];

    [extension didReceiveNotificationRequest:request withContentHandler:^(UNNotificationContent *content) {}];

    OCMVerify(times(0), [self.stubbedRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]);

    extension.capturedCompletion();

    OCMVerify(times(1), [self.stubbedRequestManager sendRequest:[OCMArg isKindOfClass:[PWMessageDeliveryRequest class]] completion:OCMOCK_ANY]);

    dispatch_sync(extension.processors.lastObject.serialQueue, ^{});
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies a processor is removed from the in-flight array once its content handler has been called.
- (void)testProcessorIsPrunedAfterDelivery {
    PushwooshNotificationServiceExtension *extension = [PushwooshNotificationServiceExtension new];

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{@"alert": @"hi"}}) content:&mockContent request:&mockRequest];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [extension didReceiveNotificationRequest:request withContentHandler:^(UNNotificationContent *content) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertEqual(extension.processors.count, 0);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

/// Verifies overriding pushwooshAppGroupsName makes badge sync use that App Group suite.
- (void)testAppGroupsOverrideIsUsedForBadges {
    PWAppGroupServiceExtension *extension = [PWAppGroupServiceExtension new];

    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:(@{@"aps": @{@"pw_badge": @"+1"}, @"pw_msg": @"1"}) content:&mockContent request:&mockRequest];

    _mockUserDefaults = OCMClassMock([NSUserDefaults class]);
    id mockNSUserDefaults = _mockUserDefaults;
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults initWithSuiteName:@"group.test.override"]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults integerForKey:OCMOCK_ANY]).andReturn(0);

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    [extension didReceiveNotificationRequest:request withContentHandler:^(UNNotificationContent *content) {
        [exp fulfill];
    }];
    PWNotificationServiceProcessor *processor = extension.processors.lastObject;

    [self waitForExpectationsWithTimeout:5 handler:nil];
    OCMVerify([mockNSUserDefaults initWithSuiteName:@"group.test.override"]);

    dispatch_sync(processor.serialQueue, ^{});
    [mockContent stopMocking];
    [mockRequest stopMocking];
}

#pragma mark - Action buttons

/// Verifies the ready-made extension base class stamps the buttons category onto the content it
/// delivers, which is the path the demo NSE takes.
- (void)testServiceExtensionDeliversContentWithTheButtonsCategory {
    PushwooshNotificationServiceExtension *extension = [PushwooshNotificationServiceExtension new];

    NSDictionary *userInfo = @{ @"aps" : @{ @"alert" : @"hi" }, @"pw_msg" : @"1", @"p" : @"hash",
                                @"pw_buttons" : @"[{\"id\":\"open_app\",\"label\":\"Open\",\"action\":\"open\"}]" };
    id mockContent; id mockRequest;
    UNNotificationRequest *request = [self requestWithUserInfo:userInfo content:&mockContent request:&mockRequest];
    NSString *expectedCategory = [PWActionButtonsRegistrar categoryIdentifierForButtons:[PWActionButtonsParser buttonsFromUserInfo:userInfo]];

    XCTestExpectation *exp = [self expectationWithDescription:@"delivered"];
    __block UNNotificationContent *delivered = nil;
    [extension didReceiveNotificationRequest:request withContentHandler:^(UNNotificationContent *content) {
        delivered = content;
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertEqualObjects(delivered, mockContent);
    OCMVerify([mockContent setCategoryIdentifier:expectedCategory]);

    [mockContent stopMocking];
    [mockRequest stopMocking];
}

@end

#endif
