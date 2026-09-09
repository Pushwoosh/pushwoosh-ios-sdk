#import <XCTest/XCTest.h>
#import "PushNotificationManager.h"
#import "PWNetworkModule.h"
#import "PWCache.h"
#import "PWTestUtils.h"
#import "PWRequestManagerMock.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import <OCMock/OCMock.h>
#import "PWRegisterUserRequest.h"
#import "PWPreferences.h"
#import "PWPostEventRequest.h"
#import "PWInAppManager.h"
#import "PWInAppManager+Internal.h"
#import "PWInAppMessagesManager.h"
#import "PWInAppStorage.h"
#import "PWResource.h"
#import "PWConfig.h"
#import "PWAppLifecycleTrackingManager.h"
#import "Pushwoosh+Internal.h"

static NSString *const KeyInAppSavedResources = @"InAppSavedResources";

@interface PWAppLifecycleTrackingManager (Test)
- (void)sendDefaultEvent:(NSString *)event;
@end

@interface PWPostEventTest : XCTestCase

@property PushNotificationManager *pushManager;
@property (nonatomic) PWInAppManager *inAppManager;
@property (nonatomic, strong) PWRequestManager *originalRequestManager;
@property (nonatomic, strong) PWRequestManagerMock *mockRequestManager;
@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;
@property (nonatomic, strong) id configMock;
@property (nonatomic, strong) id lifecycleMock;

@end

@implementation PWPostEventTest

- (void)setUp {
    [super setUp];
    [PWTestUtils setUp];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyInAppSavedResources];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [PWInAppStorage destroy];

    self.originalRequestManager = [PWNetworkModule module].requestManager;
    self.mockRequestManager = [PWRequestManagerMock new];
    [PWNetworkModule module].requestManager = self.mockRequestManager;

    self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
    [PWPlatformModule module].notificationManagerCompat = mock([PWNotificationManagerCompat class]);

    self.inAppManager = [PWInAppManager new];
    self.pushManager = [PushNotificationManager pushManager];
    [PushNotificationManager initializeWithAppCode:@"4FC89B6D14A655-46488481" appName:@"UnitTest"];

    // Silences the built-in PW_ApplicationOpen auto-post, which otherwise races these tests' own postEvent calls on the same mock.
    self.lifecycleMock = OCMPartialMock([PWAppLifecycleTrackingManager sharedManager]);
    OCMStub([self.lifecycleMock sendDefaultEvent:[OCMArg any]]);

    self.configMock = OCMPartialMock([PWConfig config]);
    OCMStub([(PWConfig *)self.configMock richMediaStyle]).andReturn(PWRichMediaStyleTypeModal);
}

- (void)tearDown {
    [self drainPendingStorageWorkBeforeTeardown];

    [self.configMock stopMocking];
    self.configMock = nil;
    [self.lifecycleMock stopMocking];
    self.lifecycleMock = nil;

    self.pushManager = nil;
    [PWNetworkModule module].requestManager = self.originalRequestManager;
    [PWPlatformModule module].notificationManagerCompat = self.originalNotificationManager;
    [PWTestUtils tearDown];
    [super tearDown];
}

/// Verifies that postEvent forwards a transport-layer error to the completion handler.
- (void)testPostEventError {
    XCTestExpectation *postEventExpectation = [self expectationWithDescription:@"postEventExpectation"];
    self.mockRequestManager.failed = YES;

    [_inAppManager postEvent:@"testEvent" withAttributes:@{} completion:^(NSError *error) {
        XCTAssertNotNil(error);
        [postEventExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
}

/// Verifies that postEvent with an empty event string completes with an error and does not send the request.
- (void)testPostEmptyEvent {
    XCTestExpectation *postEventExpectation = [self expectationWithDescription:@"postEventExpectation"];
    self.mockRequestManager.failed = NO;

    [_inAppManager postEvent:@"" withAttributes:@{} completion:^(NSError *error) {
        XCTAssertNotNil(error);
        [postEventExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
}

/// Verifies that postEvent completes with an error when SDK is initialized with an empty appCode.
- (void)testPostEventWithEmptyAppCode {
    [PushNotificationManager initializeWithAppCode:@"" appName:@"Name"];
    XCTestExpectation *postEventExpectation = [self expectationWithDescription:@"postEventExpectation"];
    self.mockRequestManager.failed = NO;

    [_inAppManager postEvent:@"testEvent" withAttributes:@{} completion:^(NSError *error) {
        XCTAssertNotNil(error);
        [postEventExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
}

/// Verifies that postEvent constructs a PWPostEventRequest with the expected payload fields.
- (void)testPostEventRequest {
    XCTestExpectation *postEventExpectation = [self expectationWithDescription:@"postEventExpectation"];
    NSString *event = @"testEvent";
    NSDictionary *attributesDict = @{@"testAttribute" : @"testAttribute"};

    __block PWRequest *postEventRequest = nil;
    self.mockRequestManager.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWPostEventRequest class]]) {
            postEventRequest = request;
        }
    };

    [_inAppManager postEvent:event withAttributes:attributesDict completion:^(NSError *error) {
        XCTAssertNil(error);
        [postEventExpectation fulfill];

        NSDictionary *requestDictionary = postEventRequest.requestDictionary;
        XCTAssertEqualObjects(requestDictionary[@"application"], [PWPreferences preferences].appCode);
        XCTAssertEqualObjects(requestDictionary[@"attributes"], attributesDict);
        XCTAssertEqualObjects(requestDictionary[@"device_type"], @(DEVICE_TYPE));
        XCTAssertEqualObjects(requestDictionary[@"event"], event);
        XCTAssertEqualObjects(requestDictionary[@"hwid"], [PWPreferences preferences].hwid);
        XCTAssertEqualObjects(requestDictionary[@"userId"], [PWPreferences preferences].userId);
        XCTAssertEqualObjects(requestDictionary[@"v"], PUSHWOOSH_VERSION);
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
}

// PWInAppStorage -finishCatalogUpdate:/-finishFullSync: hop through NSOperationQueue.mainQueue twice before
// reaching a caller; update this alongside any change to that call chain, not by re-bisecting under load.
static const NSUInteger kPWInAppStorageSettleHops = 2;

- (void)drainMainQueue {
    [self drainMainQueueForHops:kPWInAppStorageSettleHops];
}

- (void)drainMainQueueForHops:(NSUInteger)hops {
    for (NSUInteger hop = 0; hop < hops; hop++) {
        XCTestExpectation *drained = [self expectationWithDescription:@"main queue drained"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [drained fulfill];
        });
        XCTAssertEqual([XCTWaiter waitForExpectations:@[drained] timeout:2], XCTWaiterResultCompleted);
    }
}

// Flushes any PWInAppStorage callback chain still in flight before tearDown recycles the singleton, so it
// cannot fire against the next test's fresh PWRequestManagerMock.
- (void)drainPendingStorageWorkBeforeTeardown {
    [self drainMainQueueForHops:kPWInAppStorageSettleHops * 3];
}

// Releases the parked download(s) and waits for `expectation`, retrying if a new download starts first —
// that means the listener raced the release and started its own; retry instead of guessing a queue depth.
- (void)releaseDownloadsWithError:(NSError *)error untilFulfilled:(XCTestExpectation *)expectation {
    NSUInteger previousDownloadCount = self.mockRequestManager.downloadRequestCount;
    for (NSUInteger attempt = 0; attempt < 5; attempt++) {
        [self.mockRequestManager releaseDownloadsWithLocation:nil error:error];
        if ([XCTWaiter waitForExpectations:@[expectation] timeout:0.3] == XCTWaiterResultCompleted) {
            return;
        }
        NSUInteger currentDownloadCount = self.mockRequestManager.downloadRequestCount;
        if (currentDownloadCount == previousDownloadCount) {
            break;
        }
        previousDownloadCount = currentDownloadCount;
    }
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:2], XCTWaiterResultCompleted);
}

- (void)waitUntilDownloadRequestCountReaches:(NSUInteger)expected {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(PWRequestManagerMock *mock, NSDictionary *bindings) {
        return mock.downloadRequestCount >= expected;
    }];
    XCTestExpectation *reached = [self expectationForPredicate:predicate evaluatedWithObject:self.mockRequestManager handler:nil];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[reached] timeout:2], XCTWaiterResultCompleted);
}

- (NSDictionary *)catalogResponseWithCount:(NSUInteger)count {
    NSMutableArray *inApps = [NSMutableArray new];
    for (NSUInteger i = 1; i <= count; i++) {
        [inApps addObject:@{
            @"code": [NSString stringWithFormat:@"inapp-%lu", (unsigned long)i],
            @"url": [NSString stringWithFormat:@"https://example.com/inapp-%lu.zip", (unsigned long)i],
            @"updated": @1,
            @"layout": @"topbanner",
        }];
    }
    return @{ @"inApps": inApps };
}

- (void)removeLocalDataForCatalogOfCount:(NSUInteger)count {
    for (NSUInteger i = 1; i <= count; i++) {
        NSString *code = [NSString stringWithFormat:@"inapp-%lu", (unsigned long)i];
        PWResource *resource = [[PWResource alloc] initWithDictionary:@{
            @"code": code,
            @"url": @"https://example.com/x.zip",
            @"updated": @1,
        }];
        [resource deleteData];
    }
}

/// Verifies the client completion fires on the postEvent response, not gated on the still-parked getInApps
/// request — regression for the 5.5 s first-launch callback latency (ticket 103873).
- (void)testPostEvent_completionIsNotGatedOnTheInAppCatalogRequest {
    self.mockRequestManager.deferredMethods = [NSSet setWithObject:@"getInApps"];
    self.mockRequestManager.responsesByMethod = @{ @"postEvent": @{@"code": @"inapp-1"} };

    __block NSUInteger completionCalls = 0;
    __block NSError *reported = [NSError errorWithDomain:@"sentinel" code:0 userInfo:nil];
    [_inAppManager postEvent:@"testEvent" withAttributes:@{} completion:^(NSError *error) {
        completionCalls++;
        reported = error;
    }];

    XCTAssertEqual(completionCalls, 1u, @"client completion must fire on the postEvent response");
    XCTAssertNil(reported);
    XCTAssertGreaterThanOrEqual(self.mockRequestManager.deferredRequestCount, 1u, @"getInApps is still parked");

    [self.mockRequestManager releaseDeferredRequests];
    [self drainMainQueue];
    [self removeLocalDataForCatalogOfCount:1];
}

/// Verifies that the completion has already fired by the time five catalog resources start downloading —
/// the callback moment does not scale with the number of in-apps in the account.
- (void)testPostEvent_completionFiresRegardlessOfTheCatalogSize {
    self.mockRequestManager.defersDownloads = YES;
    self.mockRequestManager.responsesByMethod = @{
        @"postEvent": @{@"code": @"inapp-1"},
        @"getInApps": [self catalogResponseWithCount:5],
    };

    __block NSUInteger completionCalls = 0;
    __block NSError *reported = [NSError errorWithDomain:@"sentinel" code:0 userInfo:nil];
    [_inAppManager postEvent:@"testEvent" withAttributes:@{} completion:^(NSError *error) {
        completionCalls++;
        reported = error;
    }];

    XCTAssertEqual(completionCalls, 1u);
    XCTAssertNil(reported);
    XCTAssertEqual(self.mockRequestManager.downloadRequestCount, 5u, @"all five zips download in the background");

    [self.mockRequestManager releaseDownloadsWithLocation:nil error:[NSError errorWithDomain:@"pushwoosh" code:-7 userInfo:nil]];
    [self drainMainQueue];
    [self removeLocalDataForCatalogOfCount:5];
}

/// Verifies the presentation path waits for the triggered in-app's own zip instead of bailing out early,
/// and that whatever happens to that zip never reaches the client completion.
- (void)testPostEventInternal_resourceHandlerWaitsForItsOwnResourceDownload {
    self.mockRequestManager.defersDownloads = YES;
    self.mockRequestManager.responsesByMethod = @{
        @"postEvent": @{@"code": @"inapp-1"},
        @"getInApps": [self catalogResponseWithCount:1],
    };

    __block NSUInteger completionCalls = 0;
    __block NSError *clientError = [NSError errorWithDomain:@"sentinel" code:0 userInfo:nil];
    __block NSUInteger handlerCalls = 0;
    __block PWResource *handlerResource = nil;
    __block NSError *handlerError = nil;

    XCTestExpectation *handled = [self expectationWithDescription:@"resource handler called"];

    [self.inAppManager.inAppMessagesManager postEventInternal:@"testEvent"
                                              withAttributes:@{}
                                                  completion:^(NSError *error) {
        completionCalls++;
        clientError = error;
    }
                                             resourceHandler:^(PWResource *resource, NSString *messageHash, NSError *error) {
        handlerCalls++;
        handlerResource = resource;
        handlerError = error;
        [handled fulfill];
    }];

    XCTAssertEqual(completionCalls, 1u);
    XCTAssertNil(clientError);

    [self waitUntilDownloadRequestCountReaches:1];

    XCTAssertEqual(handlerCalls, 0u, @"presentation must still be waiting for the zip");
    XCTAssertEqual(self.mockRequestManager.downloadRequestCount, 1u);

    [self releaseDownloadsWithError:[NSError errorWithDomain:@"pushwoosh" code:-8 userInfo:@{NSLocalizedDescriptionKey : @"parked download failed"}]
                     untilFulfilled:handled];

    XCTAssertEqual(handlerCalls, 1u);
    XCTAssertNil(handlerResource);
    XCTAssertNotNil(handlerError);
    XCTAssertEqual(completionCalls, 1u, @"the resource outcome must not reach the client completion");
    XCTAssertNil(clientError);
    [self removeLocalDataForCatalogOfCount:1];
}

/// Verifies that reloadInAppsWithCompletion: still means "wait for the whole synchronization".
- (void)testReloadInApps_stillWaitsForTheWholeSynchronization {
    self.mockRequestManager.defersDownloads = YES;
    self.mockRequestManager.responsesByMethod = @{ @"getInApps": [self catalogResponseWithCount:2] };

    __block NSUInteger reloadCalls = 0;
    XCTestExpectation *reloaded = [self expectationWithDescription:@"reload finished"];
    [_inAppManager reloadInAppsWithCompletion:^(NSError *error) {
        reloadCalls++;
        [reloaded fulfill];
    }];

    [self waitUntilDownloadRequestCountReaches:2];

    XCTAssertEqual(reloadCalls, 0u, @"reload must not report while zips are still downloading");
    XCTAssertEqual(self.mockRequestManager.downloadRequestCount, 2u);

    [self releaseDownloadsWithError:[NSError errorWithDomain:@"pushwoosh" code:-9 userInfo:nil] untilFulfilled:reloaded];

    XCTAssertEqual(reloadCalls, 1u);
    [self removeLocalDataForCatalogOfCount:2];
}

/// Verifies the guard branches survive a nil completion. postEvent:withAttributes: passes completion:nil,
/// and after the refactor the guards invoke the client block directly instead of an always-present wrapper.
- (void)testPostEventWithoutCompletion_guardBranchesDoNotCrash {
    XCTAssertNoThrow([_inAppManager postEvent:@"" withAttributes:@{}]);
    XCTAssertNoThrow([_inAppManager postEvent:@"testEvent" withAttributes:@{}]);
    [self drainMainQueue];
}

@end
