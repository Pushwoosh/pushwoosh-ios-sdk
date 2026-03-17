
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWRequestManager.h"
#import "PWPreferences.h"
#import "PWNetworkModule.h"
#import "PWAppOpenRequest.h"
#import "PWRequest.h"
#import "PWConfig.h"
#import "PWSdkStateProvider.h"
#import "PWServerCommunicationManager.h"

#pragma mark - Expose private properties for testing

@interface PWRequestManager (StateTest)

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, copy) NSString *reverseProxyUrl;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *customHeaders;

- (void)sendRequestInternal:(PWRequest *)request completion:(void (^)(NSError *error))completion;

@end

@interface PWSdkStateProvider (StateTest)

@property (nonatomic) PWSdkState currentState;
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *taskQueue;

- (void)resetForTesting;

@end

#pragma mark - Test class

@interface PWRequestManagerStateTest : XCTestCase

@property (nonatomic, strong) id mockConfig;

@end

@implementation PWRequestManagerStateTest

- (void)setUp {
    [super setUp];
    [[PWSdkStateProvider sharedInstance] resetForTesting];
}

- (void)tearDown {
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [_mockConfig stopMocking];
    _mockConfig = nil;
    [PWPreferences preferences].baseUrl = [[PWPreferences preferences] defaultBaseUrl];
    [super tearDown];
}

- (PWRequestManager *)createManagerWithAllowReverseProxy:(BOOL)allow {
    _mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([_mockConfig allowReverseProxy]).andReturn(allow);
    return [PWRequestManager new];
}

#pragma mark - Scenario: Requests queued when allowReverseProxy=YES and setReverseProxy not called

/// Verifies that sendRequest queues a request when allowReverseProxy=YES and SDK is not ready.
- (void)testSendRequest_queuesWhenAllowReverseProxyAndNotReady {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    PWAppOpenRequest *request = [PWAppOpenRequest new];
    [manager sendRequest:request completion:^(NSError *error) {}];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 1);
}

/// Verifies that multiple requests are queued before setReverseProxy is called.
- (void)testSendRequest_queuesMultipleRequestsBeforeReady {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) {}];
    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) {}];
    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) {}];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 3);
}

#pragma mark - Scenario: setReverseProxy flushes queued requests

/// Verifies that queued requests are flushed when setReverseProxy is called.
- (void)testSetReverseProxy_flushesQueuedRequests {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    XCTestExpectation *expectation = [self expectationWithDescription:@"flush"];
    __block int completionCount = 0;

    id mockSession = OCMPartialMock(manager.session);
    OCMStub([mockSession dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void(^handler)(NSData *, NSURLResponse *, NSError *);
        [invocation getArgument:&handler atIndex:3];

        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
        NSString *body = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null}";
        handler([body dataUsingEncoding:NSUTF8StringEncoding], response, nil);
    }).andReturn(nil);

    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) { completionCount++; }];
    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) { completionCount++; if (completionCount == 2) [expectation fulfill]; }];

    XCTAssertEqual(completionCount, 0);

    [manager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertEqual(completionCount, 2);
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 0);
}

#pragma mark - Scenario: Requests execute immediately after setReverseProxy

/// Verifies that requests sent after setReverseProxy go through immediately.
- (void)testSendRequest_executesImmediatelyAfterSetReverseProxy {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    id mockSession = OCMPartialMock(manager.session);
    __block int dataTaskCallCount = 0;
    OCMStub([mockSession dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        dataTaskCallCount++;
        void(^handler)(NSData *, NSURLResponse *, NSError *);
        [invocation getArgument:&handler atIndex:3];

        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
        NSString *body = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null}";
        handler([body dataUsingEncoding:NSUTF8StringEncoding], response, nil);
    }).andReturn(nil);

    [manager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) {}];

    XCTAssertEqual(dataTaskCallCount, 1);
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 0);
}

#pragma mark - Scenario: allowReverseProxy=NO — no queueing

/// Verifies that requests are not queued when allowReverseProxy=NO.
- (void)testSendRequest_doesNotQueueWhenAllowReverseProxyDisabled {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:NO];

    id mockSession = OCMPartialMock(manager.session);
    __block int dataTaskCallCount = 0;
    OCMStub([mockSession dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        dataTaskCallCount++;
        void(^handler)(NSData *, NSURLResponse *, NSError *);
        [invocation getArgument:&handler atIndex:3];

        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
        NSString *body = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null}";
        handler([body dataUsingEncoding:NSUTF8StringEncoding], response, nil);
    }).andReturn(nil);

    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) {}];

    XCTAssertEqual(dataTaskCallCount, 1);
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 0);
}

#pragma mark - Scenario: Requests ignored after Error state

/// Verifies that requests are ignored when SDK is in Error state.
- (void)testSendRequest_ignoredWhenErrorState {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    [[PWSdkStateProvider sharedInstance] setError];

    __block BOOL completionCalled = NO;
    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) { completionCalled = YES; }];

    XCTAssertFalse(completionCalled);
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 0);
}

/// Verifies that queued requests are dropped when setError is called.
- (void)testSetError_dropsQueuedRequests {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    __block int completionCount = 0;
    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) { completionCount++; }];
    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) { completionCount++; }];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 2);

    [[PWSdkStateProvider sharedInstance] setError];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 0);
    XCTAssertEqual(completionCount, 0);
}

#pragma mark - Scenario: setReverseProxy after Error — no transition

/// Verifies that setReverseProxy after Error state does not flush or transition to Ready.
- (void)testSetReverseProxy_afterError_doesNotFlush {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) {}];
    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) {}];

    [[PWSdkStateProvider sharedInstance] setError];

    [manager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].currentState, PWSdkStateError);
    XCTAssertFalse([[PWSdkStateProvider sharedInstance] isReady]);
}

#pragma mark - Scenario: setReverseProxy called twice

/// Verifies that second setReverseProxy call uses updated URL but does not re-flush.
- (void)testSetReverseProxy_calledTwice_usesLatestUrl {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    id mockSession = OCMPartialMock(manager.session);
    OCMStub([mockSession dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void(^handler)(NSData *, NSURLResponse *, NSError *);
        [invocation getArgument:&handler atIndex:3];

        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
        NSString *body = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null}";
        handler([body dataUsingEncoding:NSUTF8StringEncoding], response, nil);
    }).andReturn(nil);

    [manager setReverseProxyUrl:@"https://first.example.com" headers:nil];
    [manager setReverseProxyUrl:@"https://second.example.com" headers:nil];

    XCTAssertEqualObjects(manager.reverseProxyUrl, @"https://second.example.com/");
    XCTAssertTrue([[PWSdkStateProvider sharedInstance] isReady]);
}

#pragma mark - Scenario: Queued requests use proxy URL

/// Verifies that queued requests use the proxy URL after flush.
- (void)testQueuedRequests_useProxyUrlAfterFlush {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    XCTestExpectation *expectation = [self expectationWithDescription:@"request sent"];
    __block NSURL *capturedUrl = nil;
    id mockSession = OCMPartialMock(manager.session);
    OCMStub([mockSession dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSURLRequest *req;
        [invocation getArgument:&req atIndex:2];
        capturedUrl = req.URL;

        void(^handler)(NSData *, NSURLResponse *, NSError *);
        [invocation getArgument:&handler atIndex:3];

        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
        NSString *body = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null}";
        handler([body dataUsingEncoding:NSUTF8StringEncoding], response, nil);
        [expectation fulfill];
    }).andReturn(nil);

    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) {}];

    [manager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertTrue([capturedUrl.absoluteString hasPrefix:@"https://proxy.example.com/"]);
}

#pragma mark - Scenario: State transitions are correct

/// Verifies that state is Initializing before setReverseProxy.
- (void)testState_initializingBeforeSetReverseProxy {
    [self createManagerWithAllowReverseProxy:YES];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].currentState, PWSdkStateInitializing);
}

/// Verifies that state transitions to Ready after setReverseProxy.
- (void)testState_readyAfterSetReverseProxy {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    [manager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].currentState, PWSdkStateReady);
}

/// Verifies that state transitions to Error after timeout simulation.
- (void)testState_errorAfterSetError {
    [self createManagerWithAllowReverseProxy:YES];

    [[PWSdkStateProvider sharedInstance] setError];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].currentState, PWSdkStateError);
}

#pragma mark - Scenario: loadReverseProxyFromAppGroups triggers Ready

/// Verifies that loadReverseProxyFromAppGroups transitions to Ready when URL exists.
- (void)testLoadReverseProxyFromAppGroups_transitionsToReady {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    NSString *testGroupName = @"group.com.pushwoosh.test.statetest";
    OCMStub([_mockConfig appGroupsName]).andReturn(testGroupName);

    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:testGroupName];
    [sharedDefaults setObject:@"https://proxy.example.com/" forKey:@"PWReverseProxyURL"];
    [sharedDefaults setObject:@{@"X-Auth": @"token"} forKey:@"PWCustomHeaders"];

    [manager loadReverseProxyFromAppGroups];

    XCTAssertTrue([[PWSdkStateProvider sharedInstance] isReady]);
    XCTAssertEqualObjects(manager.reverseProxyUrl, @"https://proxy.example.com/");

    [sharedDefaults removeObjectForKey:@"PWReverseProxyURL"];
    [sharedDefaults removeObjectForKey:@"PWCustomHeaders"];
}

/// Verifies that loadReverseProxyFromAppGroups does NOT transition to Ready when no URL in App Groups.
- (void)testLoadReverseProxyFromAppGroups_noUrl_staysInitializing {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    NSString *testGroupName = @"group.com.pushwoosh.test.statetest2";
    OCMStub([_mockConfig appGroupsName]).andReturn(testGroupName);

    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:testGroupName];
    [sharedDefaults removeObjectForKey:@"PWReverseProxyURL"];

    [manager loadReverseProxyFromAppGroups];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].currentState, PWSdkStateInitializing);
}

#pragma mark - Scenario: Queued requests flushed via App Groups path

/// Verifies that queued requests are flushed when loadReverseProxyFromAppGroups loads a valid URL.
- (void)testLoadReverseProxyFromAppGroups_flushesQueuedRequests {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    XCTestExpectation *expectation = [self expectationWithDescription:@"flush"];
    __block int completionCount = 0;

    id mockSession = OCMPartialMock(manager.session);
    OCMStub([mockSession dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void(^handler)(NSData *, NSURLResponse *, NSError *);
        [invocation getArgument:&handler atIndex:3];

        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
        NSString *body = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null}";
        handler([body dataUsingEncoding:NSUTF8StringEncoding], response, nil);
    }).andReturn(nil);

    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) { completionCount++; }];
    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) { completionCount++; if (completionCount == 2) [expectation fulfill]; }];

    XCTAssertEqual(completionCount, 0);

    NSString *testGroupName = @"group.com.pushwoosh.test.statetest3";
    OCMStub([_mockConfig appGroupsName]).andReturn(testGroupName);

    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:testGroupName];
    [sharedDefaults setObject:@"https://proxy.example.com/" forKey:@"PWReverseProxyURL"];

    [manager loadReverseProxyFromAppGroups];

    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertEqual(completionCount, 2);
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 0);

    [sharedDefaults removeObjectForKey:@"PWReverseProxyURL"];
}

#pragma mark - Scenario: setReverseProxy with invalid URL

/// Verifies that nil URL is rejected and state stays Initializing.
- (void)testSetReverseProxy_nilUrl_staysInitializing {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    [manager setReverseProxyUrl:nil headers:nil];

    XCTAssertNil(manager.reverseProxyUrl);
    XCTAssertEqual([PWSdkStateProvider sharedInstance].currentState, PWSdkStateInitializing);
}

/// Verifies that empty URL is rejected and state stays Initializing.
- (void)testSetReverseProxy_emptyUrl_staysInitializing {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    [manager setReverseProxyUrl:@"" headers:nil];

    XCTAssertNil(manager.reverseProxyUrl);
    XCTAssertEqual([PWSdkStateProvider sharedInstance].currentState, PWSdkStateInitializing);
}

/// Verifies that URL without http/https scheme is rejected.
- (void)testSetReverseProxy_noScheme_staysInitializing {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    [manager setReverseProxyUrl:@"proxy.example.com" headers:nil];

    XCTAssertNil(manager.reverseProxyUrl);
    XCTAssertEqual([PWSdkStateProvider sharedInstance].currentState, PWSdkStateInitializing);
}

/// Verifies that invalid URL is rejected and queued requests are NOT flushed.
- (void)testSetReverseProxy_invalidUrl_doesNotFlushQueue {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    __block BOOL completionCalled = NO;
    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) { completionCalled = YES; }];

    [manager setReverseProxyUrl:@"not-a-url" headers:nil];

    XCTAssertFalse(completionCalled);
    XCTAssertEqual([PWSdkStateProvider sharedInstance].taskQueue.count, 1);
}

#pragma mark - Scenario: setReverseProxy with custom headers

/// Verifies that custom headers are stored along with proxy URL.
- (void)testSetReverseProxy_withHeaders_storesHeaders {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    NSDictionary *headers = @{@"X-Auth": @"token123", @"X-Custom": @"value"};
    [manager setReverseProxyUrl:@"https://proxy.example.com" headers:headers];

    XCTAssertEqualObjects(manager.customHeaders[@"X-Auth"], @"token123");
    XCTAssertEqualObjects(manager.customHeaders[@"X-Custom"], @"value");
}

/// Verifies that nil headers result in empty dictionary.
- (void)testSetReverseProxy_nilHeaders_storesEmptyDict {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    [manager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTAssertNotNil(manager.customHeaders);
    XCTAssertEqual(manager.customHeaders.count, 0);
}

#pragma mark - Scenario: URL normalization

/// Verifies that trailing slash is appended to proxy URL.
- (void)testSetReverseProxy_addsTrailingSlash {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    [manager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTAssertEqualObjects(manager.reverseProxyUrl, @"https://proxy.example.com/");
}

/// Verifies that URL already with trailing slash is not doubled.
- (void)testSetReverseProxy_doesNotDoubleTrailingSlash {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    [manager setReverseProxyUrl:@"https://proxy.example.com/" headers:nil];

    XCTAssertEqualObjects(manager.reverseProxyUrl, @"https://proxy.example.com/");
}

#pragma mark - Scenario: allowReverseProxy=NO + setReverseProxy called

/// Verifies that setReverseProxy sets URL even when allowReverseProxy=NO, state is already Ready.
- (void)testSetReverseProxy_whenAllowDisabled_setsUrlButStateAlreadyReady {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:NO];

    XCTAssertEqual([PWSdkStateProvider sharedInstance].currentState, PWSdkStateReady);

    [manager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTAssertEqualObjects(manager.reverseProxyUrl, @"https://proxy.example.com/");
    XCTAssertEqual([PWSdkStateProvider sharedInstance].currentState, PWSdkStateReady);
}

#pragma mark - Scenario: Queued requests use custom headers after flush

/// Verifies that custom headers are included in flushed requests.
- (void)testQueuedRequests_useCustomHeadersAfterFlush {
    PWRequestManager *manager = [self createManagerWithAllowReverseProxy:YES];

    XCTestExpectation *expectation = [self expectationWithDescription:@"request sent"];
    __block NSDictionary *capturedHeaders = nil;
    id mockSession = OCMPartialMock(manager.session);
    OCMStub([mockSession dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSURLRequest *req;
        [invocation getArgument:&req atIndex:2];
        capturedHeaders = req.allHTTPHeaderFields;

        void(^handler)(NSData *, NSURLResponse *, NSError *);
        [invocation getArgument:&handler atIndex:3];

        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
        NSString *body = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null}";
        handler([body dataUsingEncoding:NSUTF8StringEncoding], response, nil);
        [expectation fulfill];
    }).andReturn(nil);

    [manager sendRequest:[PWAppOpenRequest new] completion:^(NSError *error) {}];

    [manager setReverseProxyUrl:@"https://proxy.example.com" headers:@{@"X-Auth": @"secret"}];

    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertEqualObjects(capturedHeaders[@"X-Auth"], @"secret");
}

@end
