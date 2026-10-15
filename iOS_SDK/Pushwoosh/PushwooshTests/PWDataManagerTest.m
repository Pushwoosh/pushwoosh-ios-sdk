#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWDataManager.h"
#import "PWConfig.h"
#import "PWAppLifecycleTrackingManager.h"
#import "PWNetworkModule.h"
#import "PWRequestManagerMock.h"
#import "PWLiveActivityRequest.h"
#import "PWUtils.h"
#import "PushwooshFramework.h"

@interface PWDataManager (TESTS)

- (void)defaultEvents;

@end

@interface PWLiveActivityRequest (Test)

- (NSString *)methodName;
- (NSDictionary *)requestDictionary;

@end

@interface PWDataManagerTest : XCTestCase

@property (nonatomic, strong) PWRequestManager *originalRequestManager;
@property (nonatomic, strong) PWRequestManagerMock *requestManagerMock;
@property (nonatomic, strong) NSMutableArray<PWLiveActivityRequest *> *liveActivityRequests;

@end

@implementation PWDataManagerTest

- (void)setUp {
    [super setUp];

    self.liveActivityRequests = [NSMutableArray array];
    self.originalRequestManager = [PWNetworkModule module].requestManager;
    self.requestManagerMock = [PWRequestManagerMock new];

    __weak typeof(self) weakSelf = self;
    self.requestManagerMock.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWLiveActivityRequest class]]) {
            [weakSelf.liveActivityRequests addObject:(PWLiveActivityRequest *)request];
        }
    };
    [PWNetworkModule module].requestManager = self.requestManagerMock;
}

- (void)tearDown {
    [PWNetworkModule module].requestManager = self.originalRequestManager;
    [super tearDown];
}

#pragma mark - Helpers

- (void)drainMainQueue {
    XCTestExpectation *drained = [self expectationWithDescription:@"main queue drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [drained fulfill];
    });
    [self waitForExpectations:@[drained] timeout:2];
}

- (NSError *)runStartWithToken:(id)token activityId:(NSString *)activityId {
    PWDataManager *manager = [PWDataManager new];
    XCTestExpectation *completed = [self expectationWithDescription:@"completion called"];
    completed.assertForOverFulfill = NO;
    __block NSInteger completionCalls = 0;
    __block NSError *receivedError = nil;

    [manager startLiveActivityWithToken:token activityId:activityId completion:^(NSError *error) {
        completionCalls++;
        receivedError = error;
        [completed fulfill];
    }];
    [self waitForExpectations:@[completed] timeout:2];
    [self drainMainQueue];

    XCTAssertEqual(completionCalls, 1);
    return receivedError;
}

/// Verifies that init schedules defaultEvents on the operation queue when isCollectingLifecycleEventsAllowed is YES.
- (void)testInitCallsDefaultEventsWhenLifecycleEventsAllowed {
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    id mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([mockConfig config]).andReturn(mockConfig);
    OCMStub([mockConfig isCollectingLifecycleEventsAllowed]).andReturn(YES);

    PWDataManager *manager = [[PWDataManager alloc] init];
    id mockManager = OCMPartialMock(manager);

    XCTestExpectation *expectation = [self expectationWithDescription:@"defaultEvents called asynchronously"];
    OCMStub([mockManager defaultEvents]).andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
    });

    [self waitForExpectations:@[expectation] timeout:2];

    [mockNetworkModule stopMocking];
    [mockConfig stopMocking];
    [mockManager stopMocking];
}

/// Verifies that init does NOT call defaultEvents when isCollectingLifecycleEventsAllowed is NO.
- (void)testInitSkipsDefaultEventsWhenLifecycleEventsDisallowed {
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    id mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([mockConfig config]).andReturn(mockConfig);
    OCMStub([mockConfig isCollectingLifecycleEventsAllowed]).andReturn(NO);

    PWDataManager *manager = [[PWDataManager alloc] init];
    id mockManager = OCMPartialMock(manager);
    OCMReject([mockManager defaultEvents]);

    XCTestExpectation *settle = [self expectationWithDescription:@"operation queue drained"];
    [[NSOperationQueue currentQueue] addOperationWithBlock:^{
        [settle fulfill];
    }];
    [self waitForExpectations:@[settle] timeout:2];

    OCMVerifyAll(mockManager);

    [mockNetworkModule stopMocking];
    [mockConfig stopMocking];
    [mockManager stopMocking];
}

#pragma mark - Start Live Activity with invalid token

/// Verifies that an empty token sends no setActivityToken request and fails the completion with a PWErrorDomain error.
- (void)testStartLiveActivity_emptyToken_completesWithErrorWithoutRequest {
    NSError *error = [self runStartWithToken:@"" activityId:@"activity-1"];

    XCTAssertEqualObjects(error.domain, PWErrorDomain);
    XCTAssertEqual(self.liveActivityRequests.count, 0);
}

/// Verifies that a nil token sends no setActivityToken request and fails the completion with a PWErrorDomain error.
- (void)testStartLiveActivity_nilToken_completesWithErrorWithoutRequest {
    NSError *error = [self runStartWithToken:nil activityId:@"activity-1"];

    XCTAssertEqualObjects(error.domain, PWErrorDomain);
    XCTAssertEqual(self.liveActivityRequests.count, 0);
}

/// Verifies that an NSNull token sends no setActivityToken request and fails the completion with a PWErrorDomain error.
- (void)testStartLiveActivity_nullToken_completesWithErrorWithoutRequest {
    NSError *error = [self runStartWithToken:[NSNull null] activityId:@"activity-1"];

    XCTAssertEqualObjects(error.domain, PWErrorDomain);
    XCTAssertEqual(self.liveActivityRequests.count, 0);
}

/// Verifies that a non-string token sends no setActivityToken request and fails the completion with a PWErrorDomain error.
- (void)testStartLiveActivity_numberToken_completesWithErrorWithoutRequest {
    NSError *error = [self runStartWithToken:@42 activityId:@"activity-1"];

    XCTAssertEqualObjects(error.domain, PWErrorDomain);
    XCTAssertEqual(self.liveActivityRequests.count, 0);
}

/// Verifies that an empty token is reported through an error-level log mentioning the token.
- (void)testStartLiveActivity_emptyToken_logsError {
    id logMock = OCMClassMock([PushwooshLog class]);
    OCMExpect([logMock pushwooshLog:PW_LL_ERROR className:OCMOCK_ANY message:[OCMArg checkWithBlock:^BOOL(NSString *message) {
        return [message.lowercaseString containsString:@"token"];
    }]]);

    [self runStartWithToken:@"" activityId:@"activity-1"];

    OCMVerifyAll(logMock);
    [logMock stopMocking];
}

/// Verifies that the empty-token failure is delivered on the main thread when start is called from a background queue.
- (void)testStartLiveActivity_emptyTokenFromBackgroundQueue_completesOnMainThread {
    PWDataManager *manager = [PWDataManager new];
    XCTestExpectation *completed = [self expectationWithDescription:@"completion called"];
    __block BOOL calledOnMainThread = NO;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [manager startLiveActivityWithToken:@"" activityId:@"activity-1" completion:^(NSError *error) {
            calledOnMainThread = [NSThread isMainThread];
            [completed fulfill];
        }];
    });
    [self waitForExpectations:@[completed] timeout:2];

    XCTAssertTrue(calledOnMainThread);
}

/// Verifies that an empty token without a completion sends no setActivityToken request.
- (void)testStartLiveActivity_emptyTokenWithoutCompletion_sendsNoRequest {
    PWDataManager *manager = [PWDataManager new];

    [manager startLiveActivityWithToken:@"" activityId:@"activity-1" completion:nil];
    [self drainMainQueue];

    XCTAssertEqual(self.liveActivityRequests.count, 0);
}

/// Verifies that the legacy two-argument Pushwoosh overload sends no setActivityToken request for an empty token.
- (void)testPublicStartLiveActivity_emptyToken_sendsNoRequest {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[Pushwoosh sharedInstance] startLiveActivityWithToken:@"" activityId:@"activity-1"];
#pragma clang diagnostic pop
    [self drainMainQueue];

    XCTAssertEqual(self.liveActivityRequests.count, 0);
}

#pragma mark - Start Live Activity with valid token

/// Verifies that a valid token sends one setActivityToken request carrying the token and activity id.
- (void)testStartLiveActivity_validToken_sendsSetActivityTokenRequest {
    [self runStartWithToken:@"token-1" activityId:@"activity-1"];

    XCTAssertEqual(self.liveActivityRequests.count, 1);
    PWLiveActivityRequest *request = self.liveActivityRequests.firstObject;
    NSDictionary *body = [request requestDictionary];
    XCTAssertEqualObjects([request methodName], @"setActivityToken");
    XCTAssertEqualObjects(body[@"activity_token"], @"token-1");
    XCTAssertEqualObjects(body[@"activity_id"], @"activity-1");
}

/// Verifies that a successful request completes the start with a nil error.
- (void)testStartLiveActivity_requestSucceeds_completesWithNilError {
    NSError *error = [self runStartWithToken:@"token-1" activityId:@"activity-1"];

    XCTAssertNil(error);
}

/// Verifies that a failed request passes the request error to the start completion.
- (void)testStartLiveActivity_requestFails_completesWithRequestError {
    self.requestManagerMock.failed = YES;

    NSError *error = [self runStartWithToken:@"token-1" activityId:@"activity-1"];

    XCTAssertEqualObjects(error.localizedDescription, @"Testing error");
}

#pragma mark - Stop Live Activity

/// Verifies that stop sends one setActivityToken request with the activity id and no token.
- (void)testStopLiveActivity_activityId_sendsRequestWithoutToken {
    PWDataManager *manager = [PWDataManager new];
    XCTestExpectation *completed = [self expectationWithDescription:@"completion called"];

    [manager stopLiveActivityWith:@"activity-1" completion:^(NSError *error) {
        [completed fulfill];
    }];
    [self waitForExpectations:@[completed] timeout:2];

    XCTAssertEqual(self.liveActivityRequests.count, 1);
    NSDictionary *body = [self.liveActivityRequests.firstObject requestDictionary];
    XCTAssertNil(body[@"activity_token"]);
    XCTAssertEqualObjects(body[@"activity_id"], @"activity-1");
}

@end
