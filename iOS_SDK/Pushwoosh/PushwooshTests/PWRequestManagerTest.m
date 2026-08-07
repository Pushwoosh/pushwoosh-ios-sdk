
#import "PWAppOpenRequest.h"
#import "PWRequestManager.h"
#import "PWPreferences.h"
#import "PWNetworkModule.h"
#import "PWRequest.h"
#import "PushwooshFramework.h"
#import "PWConfig.h"
#import "PWSdkStateProvider.h"
#import "PWRetryQueue.h"
#import "PWMessageDeliveryRequest.h"
#import "PWSetTagsRequest.h"
#import "PWRequest+Internal.h"
#import "PWReplayRequest.h"

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import <objc/runtime.h>

@interface PWSdkStateProvider (Test)
- (void)resetForTesting;
@end

@interface PWRequestManager (Test)

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) PWRetryQueue *retryQueue;

- (NSString *)baseUrl;
- (void)setReverseProxyUrl:(NSString *)url headers:(NSDictionary<NSString *, NSString *> *)headers;
- (NSMutableURLRequest *)prepareRequest:(NSString *)requestUrl jsonRequestData:(NSString *)jsonRequestData;
- (void)sendRequestInternal:(PWRequest *)request completion:(void (^)(NSError *error))completion;
- (void)processResponse:(NSHTTPURLResponse *)httpResponse responseData:(NSData *)responseData request:(PWRequest *)request url:(NSString *)requestUrl requestData:(NSString *)requestData error:(NSError **)outError;
- (NSString *)getApiToken;
- (void)sendTags:(PWSetTagsRequest *)request completion:(void (^)(NSError *error))completion;
- (void)pinApplicationForRequest:(PWRequest *)request;
- (BOOL)isUsingReverseProxy;
- (NSString *)registrableDomainOfHost:(NSString *)host;
- (BOOL)shouldBypassGRPCForRequest:(PWRequest *)request;

- (void)onRequestError:(PWRequest *)request
           requestData:(NSString *)requestData
          httpResponse:(NSHTTPURLResponse *)httpResponse
                 error:(NSError *)error;

@end

@implementation NSURLSession (Mock)

static NSURLResponse *gResponse;
static NSData *gResponseData;
static NSError *gResponseError;

+ (void)setUp {
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(dataTaskWithRequest: completionHandler:)), class_getInstanceMethod(self, @selector(mock_dataTaskWithRequest: completionHandler:)));
}

+ (void)tearDown {
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(dataTaskWithRequest: completionHandler:)), class_getInstanceMethod(self, @selector(mock_dataTaskWithRequest: completionHandler:)));
	gResponse = nil;
	gResponseData = nil;
	gResponseError = nil;
}

+ (void)injectResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
	gResponse = response;
	gResponseData = data;
	gResponseError = error;
}

- (NSURLSessionDataTask *)mock_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler {
	if (completionHandler) {
		completionHandler(gResponseData, gResponse, gResponseError);
	}
	return nil;
}

@end

@interface PWRequestManagerTest : XCTestCase

@property (nonatomic, strong) PWRequestManager *requestManager;
@property (nonatomic, copy) NSString *savedAppCode;
@property (nonatomic, copy) NSString *savedBaseUrl;
@property (nonatomic, copy) NSDictionary *savedActiveApplicationRecord;
@property (nonatomic, strong) id partialManagerMock;

@end

static id _mockNSBundle;

@implementation PWRequestManagerTest

- (void)setUp {
    [super setUp];
	[[PWNetworkModule module] inject:self];

	[NSURLSession setUp];

    if ([PWPreferences preferences].appCode.length == 0) {
        [PWPreferences preferences].appCode = @"TEST-APPCODE-REQMGR";
    }

    _savedAppCode = [[PWPreferences preferences].appCode copy];
    _savedBaseUrl = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];
    _savedActiveApplicationRecord = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_ACTIVE_APPLICATION"] copy];

    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [[PWSdkStateProvider sharedInstance] setReady];
}

- (void)tearDown {
    [NSURLSession tearDown];

    [_partialManagerMock stopMocking];
    _partialManagerMock = nil;

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    if (_savedActiveApplicationRecord) {
        [[NSUserDefaults standardUserDefaults] setObject:_savedActiveApplicationRecord forKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    [PWPreferences preferences].appCode = _savedAppCode;

    NSString *restoredBaseUrl = _savedBaseUrl.length > 0 ? _savedBaseUrl : [[PWPreferences preferences] defaultBaseUrl];
    if (restoredBaseUrl.length > 0) {
        [[PWPreferences preferences] updateBaseUrl:restoredBaseUrl];
    }
    if (_savedBaseUrl.length == 0) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_BASEURL"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [super tearDown];
}

- (void)testAppOpen {
	NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
	NSString *responseData = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null}";
	[NSURLSession injectResponse:httpResponse data:[responseData dataUsingEncoding:NSUTF8StringEncoding] error:nil];
	
	XCTestExpectation *appOpenExpectation = [self expectationWithDescription:@"applicationOpen resonse"];
	
	PWAppOpenRequest *request = [PWAppOpenRequest new];
    [_requestManager sendRequest:request completion:^(NSError *error) {
        XCTAssertNil(error);
		[appOpenExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testUrlChange {
	XCTAssertEqualObjects([PWPreferences preferences].baseUrl, [[PWPreferences preferences] defaultBaseUrl]);
	
	NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
	NSString *responseData = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null,\"base_url\":\"https://test.pushwoosh.com/json/4.2/\"}";
	[NSURLSession injectResponse:httpResponse data:[responseData dataUsingEncoding:NSUTF8StringEncoding] error:nil];
	
	XCTestExpectation *appOpenExpectation = [self expectationWithDescription:@"applicationOpen resonse"];
	
	PWAppOpenRequest *request = [PWAppOpenRequest new];
	[_requestManager sendRequest:request completion:^(NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects([PWPreferences preferences].baseUrl, @"https://test.pushwoosh.com/json/4.2/");
		[appOpenExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:1 handler:nil];
	
	
	// Test url reset after bad request
	XCTestExpectation *appOpenExpectation2 = [self expectationWithDescription:@"applicationOpen resonse2"];
	responseData = @"{\"status_message\":\"OK\",\"response\":null}";
	[NSURLSession injectResponse:httpResponse data:[responseData dataUsingEncoding:NSUTF8StringEncoding] error:nil];
	request = [PWAppOpenRequest new];
    [_requestManager sendRequest:request completion:^(NSError *error) {
        XCTAssertEqualObjects([PWPreferences preferences].baseUrl, [[PWPreferences preferences] defaultBaseUrl]);
		[appOpenExpectation2 fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:1 handler:nil];
}

/// Verifies that getApiToken returns the modern pushwooshApiToken value from PWConfig.
- (void)testPushwooshApiTokenAvailable {
    NSString *pushwooshApiToken = @"qwertyuiopasdfghjklzxcvbnm_new";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig pushwooshApiToken]).andReturn(pushwooshApiToken);

    XCTAssertEqualObjects(pushwooshApiToken, [_requestManager getApiToken]);

    [mockConfig stopMocking];
}

/// Verifies that getApiToken returns the legacy apiToken value from PWConfig when modern token is absent.
- (void)testPwApiTokenAvailable {
    NSString *pwApiToken = @"qwertyuiopasdfghjklzxcvbnm_old";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig apiToken]).andReturn(pwApiToken);

    XCTAssertEqualObjects(pwApiToken, [_requestManager getApiToken]);

    [mockConfig stopMocking];
}

- (void)testNoHttpResponse {
	NSHTTPURLResponse *httpResponse = nil;
	NSString *responseData = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null}";
	[NSURLSession injectResponse:httpResponse data:[responseData dataUsingEncoding:NSUTF8StringEncoding] error:nil];
	
	XCTestExpectation *appOpenExpectation = [self expectationWithDescription:@"applicationOpen resonse"];
	
	PWAppOpenRequest *request = [PWAppOpenRequest new];
    [_requestManager sendRequest:request completion:^(NSError *error) {
        XCTAssertNotNil(error);
		[appOpenExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testNotJsonFormat {
	NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
	NSString *responseData = @")Not json format";
	[NSURLSession injectResponse:httpResponse data:[responseData dataUsingEncoding:NSUTF8StringEncoding] error:nil];
	
	XCTestExpectation *appOpenExpectation = [self expectationWithDescription:@"applicationOpen resonse"];
	
	PWAppOpenRequest *request = [PWAppOpenRequest new];
    [_requestManager sendRequest:request completion:^(NSError *error) {
        XCTAssertNotNil(error);
		[appOpenExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testNoStatusCode {
	NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
	NSString *responseData = @"{\"response\":null}";
	[NSURLSession injectResponse:httpResponse data:[responseData dataUsingEncoding:NSUTF8StringEncoding] error:nil];
	
	XCTestExpectation *appOpenExpectation = [self expectationWithDescription:@"applicationOpen resonse"];
	
	PWAppOpenRequest *request = [PWAppOpenRequest new];
    [_requestManager sendRequest:request completion:^(NSError *error) {
        XCTAssertNotNil(error);
		[appOpenExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testNoResponse {
	NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
	NSString *responseData = @"{\"status_code\":200,\"status_message\":\"OK\"}";
	[NSURLSession injectResponse:httpResponse data:[responseData dataUsingEncoding:NSUTF8StringEncoding] error:nil];
	
	XCTestExpectation *appOpenExpectation = [self expectationWithDescription:@"applicationOpen resonse"];
	
	PWAppOpenRequest *request = [PWAppOpenRequest new];
	[_requestManager sendRequest:request completion:^(NSError *error) {
		[appOpenExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:1 handler:nil];
	// cannot guarantee anything, just do not crash
	//XCTAssertNil(request.error);
}

- (void)testStatusCodeString {
	NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
	NSString *responseData = @"{\"status_code\":\"200\",\"status_message\":\"OK\",\"response\":null}";
	[NSURLSession injectResponse:httpResponse data:[responseData dataUsingEncoding:NSUTF8StringEncoding] error:nil];
	
	XCTestExpectation *appOpenExpectation = [self expectationWithDescription:@"applicationOpen resonse"];
	
	PWAppOpenRequest *request = [PWAppOpenRequest new];
    [_requestManager sendRequest:request completion:^(NSError *error) {
        XCTAssertNotNil(error);
		[appOpenExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testStatusCodeArray {
	NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
	NSString *responseData = @"{\"status_code\":[],\"status_message\":\"OK\",\"response\":null}";
	[NSURLSession injectResponse:httpResponse data:[responseData dataUsingEncoding:NSUTF8StringEncoding] error:nil];
	
	XCTestExpectation *appOpenExpectation = [self expectationWithDescription:@"applicationOpen resonse"];
	
	PWAppOpenRequest *request = [PWAppOpenRequest new];
    [_requestManager sendRequest:request completion:^(NSError *error) {
        XCTAssertNotNil(error);
		[appOpenExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testStatusCodeNotOk {
	NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
	NSString *responseData = @"{\"status_code\":\"210\",\"status_message\":\"Not OK\",\"response\":null}";
	[NSURLSession injectResponse:httpResponse data:[responseData dataUsingEncoding:NSUTF8StringEncoding] error:nil];
	
	XCTestExpectation *appOpenExpectation = [self expectationWithDescription:@"applicationOpen resonse"];
	
	PWAppOpenRequest *request = [PWAppOpenRequest new];
    [_requestManager sendRequest:request completion:^(NSError *error) {
        XCTAssertNotNil(error);
		[appOpenExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testHeaderAuthExist {
    NSString *apiToken = @"somEpusHwooSHtOkenMocK";
    NSString *correctFormat = [NSString stringWithFormat:@"Token %@", apiToken];
    id mockNSMutableURLRequest = OCMClassMock([NSMutableURLRequest class]);
    OCMStub([mockNSMutableURLRequest alloc]).andReturn(mockNSMutableURLRequest);
    OCMStub([mockNSMutableURLRequest initWithURL:OCMOCK_ANY]).andReturn(mockNSMutableURLRequest);
    id mockPWConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfig apiToken]).andReturn(apiToken);

    [_requestManager prepareRequest:@"" jsonRequestData:@""];

    OCMVerify([mockNSMutableURLRequest setValue:correctFormat forHTTPHeaderField:@"Authorization"]);

    [mockNSMutableURLRequest stopMocking];
    [mockPWConfig stopMocking];
}

#pragma mark - SDK-814: request-blocking guard

/// SDK-814: Verifies that sendRequestInternal blocks the request with a "Base URL is not configured yet" error when baseUrl is empty and no reverse proxy is set.
- (void)testMakeRequestBlocksWhenBaseUrlNotConfigured {
    id mockPrefs = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPrefs baseUrl]).andReturn(nil);

    XCTestExpectation *expectation = [self expectationWithDescription:@"blocked"];
    PWAppOpenRequest *request = [PWAppOpenRequest new];

    [_requestManager sendRequestInternal:request completion:^(NSError *error) {
        XCTAssertNotNil(error);
        XCTAssertTrue([error.localizedDescription containsString:@"Base URL is not configured yet"], @"Expected blocked-error message, got: %@", error.localizedDescription);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    [mockPrefs stopMocking];
}

/// SDK-814: Verifies that the reverse proxy URL is independent of prefs.baseUrl funneling — set proxy + clear KeyBaseUrl, baseUrl reader returns the proxy URL not the underlying preferences value.
- (void)testSetReverseProxyStillWorksAfterUpdateBaseUrlFunnel {
    NSString *priorBaseUrl = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_BASEURL"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [_requestManager setReverseProxyUrl:@"https://proxy-only.example.com" headers:nil];

    XCTAssertEqualObjects([_requestManager baseUrl], @"https://proxy-only.example.com/");

    @synchronized (_requestManager) {
        [_requestManager setValue:nil forKey:@"reverseProxyUrl"];
    }
    if (priorBaseUrl) {
        [[NSUserDefaults standardUserDefaults] setObject:priorBaseUrl forKey:@"Pushwoosh_BASEURL"];
    }
}

/// Verifies the manager-level gate enqueues a cacheable request into the retry queue on a transient (500) failure.
- (void)testCacheableTransientFailure_enqueuesToRetryQueue {
    id savedQueue = _requestManager.retryQueue;
    id mockQueue = OCMClassMock([PWRetryQueue class]);
    _requestManager.retryQueue = mockQueue;
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://example.com"] statusCode:500 HTTPVersion:nil headerFields:nil];
    [NSURLSession injectResponse:response data:[@"{}" dataUsingEncoding:NSUTF8StringEncoding] error:nil];

    PWMessageDeliveryRequest *request = [PWMessageDeliveryRequest new];
    XCTestExpectation *exp = [self expectationWithDescription:@"done"];
    [_requestManager sendRequestInternal:request completion:^(NSError *error) { [exp fulfill]; }];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    OCMVerify([mockQueue enqueueRequest:request baseUrl:OCMOCK_ANY]);
    _requestManager.retryQueue = savedQueue;
    [mockQueue stopMocking];
}

/// Verifies the gate does NOT enqueue a non-cacheable request even on a transient (500) failure.
- (void)testNonCacheableTransientFailure_doesNotEnqueue {
    id savedQueue = _requestManager.retryQueue;
    id mockQueue = OCMClassMock([PWRetryQueue class]);
    OCMReject([mockQueue enqueueRequest:OCMOCK_ANY baseUrl:OCMOCK_ANY]);
    _requestManager.retryQueue = mockQueue;
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://example.com"] statusCode:500 HTTPVersion:nil headerFields:nil];
    [NSURLSession injectResponse:response data:[@"{}" dataUsingEncoding:NSUTF8StringEncoding] error:nil];

    PWAppOpenRequest *request = [PWAppOpenRequest new];
    XCTestExpectation *exp = [self expectationWithDescription:@"done"];
    [_requestManager sendRequestInternal:request completion:^(NSError *error) { [exp fulfill]; }];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    _requestManager.retryQueue = savedQueue;
    [mockQueue stopMocking];
}

/// Verifies the gate does NOT enqueue a cacheable request on a permanent (4xx) failure — only transient codes retry.
- (void)testCacheablePermanentFailure_doesNotEnqueue {
    id savedQueue = _requestManager.retryQueue;
    id mockQueue = OCMClassMock([PWRetryQueue class]);
    OCMReject([mockQueue enqueueRequest:OCMOCK_ANY baseUrl:OCMOCK_ANY]);
    _requestManager.retryQueue = mockQueue;
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://example.com"] statusCode:400 HTTPVersion:nil headerFields:nil];
    [NSURLSession injectResponse:response data:[@"{}" dataUsingEncoding:NSUTF8StringEncoding] error:nil];

    PWMessageDeliveryRequest *request = [PWMessageDeliveryRequest new];
    XCTestExpectation *exp = [self expectationWithDescription:@"done"];
    [_requestManager sendRequestInternal:request completion:^(NSError *error) { [exp fulfill]; }];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    _requestManager.retryQueue = savedQueue;
    [mockQueue stopMocking];
}

#pragma mark - SDK-882: send-time pin

/// SDK-882: Verifies the pin is atomic — hammering it while switching on another thread must never produce one application's code next to the other's host.
- (void)testPinApplicationIsAtomicDuringConcurrentSwitch {
    XCTAssertFalse([_requestManager isUsingReverseProxy], @"this test asserts the non-proxy pin path");

    NSString *appA = @"AAAAA-11111";
    NSString *appB = @"BBBBB-22222";
    NSString *urlA = @"https://region-a.example.com/json/1.3/";
    NSString *urlB = @"https://region-b.example.com/json/1.3/";

    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:appA baseUrl:urlA]);

    XCTestExpectation *finished = [self expectationWithDescription:@"switches finished"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        for (NSInteger i = 0; i < 40; i++) {
            if (i % 2 == 0) {
                [[PWPreferences preferences] switchToApplicationWithAppCode:appB baseUrl:urlB];
            } else {
                [[PWPreferences preferences] switchToApplicationWithAppCode:appA baseUrl:urlA];
            }
        }
        [finished fulfill];
    });

    for (NSInteger i = 0; i < 400; i++) {
        PWRequest *request = [PWRequest new];
        [_requestManager pinApplicationForRequest:request];

        BOOL isPairA = [request.pinnedAppCode isEqualToString:appA] && [request.pinnedBaseUrl isEqualToString:urlA];
        BOOL isPairB = [request.pinnedAppCode isEqualToString:appB] && [request.pinnedBaseUrl isEqualToString:urlB];
        XCTAssertTrue(isPairA || isPairB,
                      @"torn pin: application %@ paired with host %@", request.pinnedAppCode, request.pinnedBaseUrl);
    }

    [self waitForExpectationsWithTimeout:20 handler:nil];
}

/// SDK-882: Verifies the pin takes BOTH halves from one snapshot — a switch landing between the two reads must not pair one application's code with the other's host.
- (void)testPinDoesNotTearWhenASwitchLandsMidPin {
    NSString *appA = @"AAAAA-11111";
    NSString *appB = @"BBBBB-22222";
    NSString *urlA = @"https://region-a.example.com/json/1.3/";
    NSString *urlB = @"https://region-b.example.com/json/1.3/";

    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:appA baseUrl:urlA]);

    id mockPrefs = OCMPartialMock([PWPreferences preferences]);
    NSDictionary *pairA = @{ @"appCode": appA, @"baseUrl": urlA };
    __block BOOL alreadySwitched = NO;
    OCMStub([mockPrefs activeApplicationSnapshot]).andDo(^(NSInvocation *invocation) {
        if (!alreadySwitched) {
            alreadySwitched = YES;
            [[PWPreferences preferences] switchToApplicationWithAppCode:appB baseUrl:urlB];
        }
    }).andReturn(pairA);

    PWRequest *request = [PWRequest new];
    [_requestManager pinApplicationForRequest:request];

    XCTAssertEqualObjects(request.pinnedAppCode, appA);
    XCTAssertEqualObjects([PWPreferences preferences].baseUrl, urlB, @"the injected switch must really have landed");
    XCTAssertEqualObjects(request.pinnedBaseUrl, urlA,
                          @"the pinned host must come from the same snapshot as the pinned application code");

    [mockPrefs stopMocking];
}

/// SDK-882: Verifies a reverse proxy still outranks the pinned endpoint — it is a transport override, not part of the switched pair.
- (void)testPinUsesReverseProxyWhenConfigured {
    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"]);
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com/" headers:nil];

    PWRequest *request = [PWRequest new];
    [_requestManager pinApplicationForRequest:request];

    XCTAssertEqualObjects(request.pinnedAppCode, @"AAAAA-11111");
    XCTAssertEqualObjects(request.pinnedBaseUrl, @"https://proxy.example.com/");

    @synchronized (_requestManager) {
        [_requestManager setValue:nil forKey:@"reverseProxyUrl"];
    }
}

/// SDK-882: Verifies the pin is a no-op without an active-application record, so legacy installs keep the pre-882 behaviour bit-for-bit.
- (void)testPinApplicationDoesNothingWithoutAnActiveApplicationRecord {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    XCTAssertFalse([PWPreferences hasActiveApplicationRecord]);

    PWRequest *request = [PWRequest new];
    [_requestManager pinApplicationForRequest:request];

    XCTAssertNil(request.pinnedAppCode);
    XCTAssertNil(request.pinnedBaseUrl);
}

/// SDK-882: Verifies a server rotation to another domain is still applied — the cross-domain signal is a warning, never a block.
- (void)testServerBaseUrlOutsideSelectedDomainIsStillApplied {
    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"]);

    PWRequest *request = [PWAppOpenRequest new];
    [_requestManager pinApplicationForRequest:request];

    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://region-a.example.com"] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSData *responseData = [@"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null,\"base_url\":\"https://elsewhere.example.org/json/1.3/\"}" dataUsingEncoding:NSUTF8StringEncoding];

    NSError *error = nil;
    [_requestManager processResponse:httpResponse responseData:responseData request:request url:@"https://region-a.example.com/applicationOpen" requestData:@"{}" error:&error];

    XCTAssertEqualObjects([PWPreferences preferences].baseUrl, @"https://elsewhere.example.org/json/1.3/");
}

/// SDK-882: Verifies a replayed request never moves the endpoint, whatever base_url its response carries.
- (void)testServerBaseUrlFromAReplayIsIgnored {
    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"]);

    PWReplayRequest *replay = [[PWReplayRequest alloc] initWithMethodName:@"pushStat"
                                                        requestDictionary:@{@"application": @"AAAAA-11111"}
                                                        requestIdentifier:@"rid-1"
                                                        shouldWrapRequest:YES
                                                                  baseUrl:@"https://region-a.example.com/json/1.3/"];

    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://region-a.example.com"] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSData *responseData = [@"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null,\"base_url\":\"https://replay-moved.example.org/json/1.3/\"}" dataUsingEncoding:NSUTF8StringEncoding];

    NSError *error = nil;
    [_requestManager processResponse:httpResponse responseData:responseData request:replay url:@"https://region-a.example.com/pushStat" requestData:@"{}" error:&error];

    XCTAssertEqualObjects([PWPreferences preferences].baseUrl, @"https://region-a.example.com/json/1.3/");
}

/// SDK-882: Verifies an already-pinned request keeps its original pair, so a session retry cannot re-target mid-backoff.
- (void)testPinApplicationDoesNotRepinAnAlreadyPinnedRequest {
    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"]);

    PWRequest *request = [PWRequest new];
    [_requestManager pinApplicationForRequest:request];
    XCTAssertEqualObjects(request.pinnedAppCode, @"AAAAA-11111");

    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"BBBBB-22222" baseUrl:@"https://region-b.example.com/json/1.3/"]);
    [_requestManager pinApplicationForRequest:request];

    XCTAssertEqualObjects(request.pinnedAppCode, @"AAAAA-11111");
    XCTAssertEqualObjects(request.pinnedBaseUrl, @"https://region-a.example.com/json/1.3/");
}

/// SDK-882: Verifies a replayed request is never pinned — its body and URL are already frozen.
- (void)testPinApplicationDoesNotPinAReplayRequest {
    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"]);

    PWReplayRequest *replay = [[PWReplayRequest alloc] initWithMethodName:@"pushStat"
                                                        requestDictionary:@{@"application": @"AAAAA-11111"}
                                                        requestIdentifier:@"rid-pin"
                                                        shouldWrapRequest:YES
                                                                  baseUrl:@"https://region-a.example.com/json/1.3/"];
    [_requestManager pinApplicationForRequest:replay];

    XCTAssertNil(replay.pinnedAppCode);
    XCTAssertNil(replay.pinnedBaseUrl);
}

/// SDK-882: Verifies a queued retry entry freezes the host the request was actually addressed to.
- (void)testCacheableTransientFailure_freezesTheSelectedHostOnTheQueuedEntry {
    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"]);

    id savedQueue = _requestManager.retryQueue;
    id mockQueue = OCMClassMock([PWRetryQueue class]);
    _requestManager.retryQueue = mockQueue;
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://region-a.example.com"] statusCode:500 HTTPVersion:nil headerFields:nil];
    [NSURLSession injectResponse:response data:[@"{}" dataUsingEncoding:NSUTF8StringEncoding] error:nil];

    PWMessageDeliveryRequest *request = [PWMessageDeliveryRequest new];
    XCTestExpectation *exp = [self expectationWithDescription:@"done"];
    [_requestManager sendRequestInternal:request completion:^(NSError *error) { [exp fulfill]; }];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    OCMVerify([mockQueue enqueueRequest:request baseUrl:@"https://region-a.example.com/json/1.3/"]);
    _requestManager.retryQueue = savedQueue;
    [mockQueue stopMocking];
}

#pragma mark - SDK-882: gRPC bypass routing

/// SDK-882: Verifies gRPC is bypassed when the selected endpoint is not the host the gRPC transport is fixed to.
- (void)testShouldBypassGRPCWhenSelectedHostDiffersFromGrpcHost {
    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"]);

    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig grpcHost]).andReturn(@"grpc.pushwoosh.com");

    PWRequest *request = [PWRequest new];
    [_requestManager pinApplicationForRequest:request];

    XCTAssertTrue([_requestManager shouldBypassGRPCForRequest:request]);
    [mockConfig stopMocking];
}

/// SDK-882: Verifies gRPC is kept when the selected endpoint is the very host the gRPC transport targets.
- (void)testShouldNotBypassGRPCWhenSelectedHostMatchesGrpcHost {
    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"AAAAA-11111" baseUrl:@"https://grpc.pushwoosh.com/json/1.3/"]);

    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig grpcHost]).andReturn(@"grpc.pushwoosh.com");

    PWRequest *request = [PWRequest new];
    [_requestManager pinApplicationForRequest:request];

    XCTAssertFalse([_requestManager shouldBypassGRPCForRequest:request]);
    [mockConfig stopMocking];
}

/// SDK-882: Verifies an install that never selected an application at runtime keeps using gRPC unchanged.
- (void)testShouldNotBypassGRPCWithoutAnActiveApplicationRecord {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    XCTAssertFalse([PWPreferences hasActiveApplicationRecord]);

    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig grpcHost]).andReturn(@"grpc.pushwoosh.com");

    XCTAssertFalse([_requestManager shouldBypassGRPCForRequest:[PWRequest new]]);
    [mockConfig stopMocking];
}

/// SDK-882: Verifies the registrable-domain approximation used by the rotation warning.
- (void)testRegistrableDomainOfHost {
    XCTAssertEqualObjects([_requestManager registrableDomainOfHost:@"AAAAA-11111.api.pushwoosh.com"], @"pushwoosh.com");
    XCTAssertEqualObjects([_requestManager registrableDomainOfHost:@"pushwoosh.com"], @"pushwoosh.com");
    XCTAssertEqualObjects([_requestManager registrableDomainOfHost:@"localhost"], @"localhost");
    XCTAssertEqualObjects([_requestManager registrableDomainOfHost:@"deep.sub.example-region.com"], @"example-region.com");
}

#pragma mark - SDK-882 (A2): setTags coalescing across an application switch

/// SDK-882: Verifies that switching applications inside the one-second setTags window flushes the pending tags to the previous application instead of merging the next application's tags into them.
- (void)testSetTagsCoalescingIsDrainedOnApplicationSwitch {
    NSString *urlA = @"https://region-a.example.com/json/1.3/";
    NSString *urlB = @"https://region-b.example.com/json/1.3/";

    id mockManager = OCMPartialMock(_requestManager);
    _partialManagerMock = mockManager;
    NSMutableArray<NSString *> *sentApplications = [NSMutableArray array];
    XCTestExpectation *secondSend = [self expectationWithDescription:@"second setTags sent"];
    OCMStub([mockManager sendRequestInternal:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWRequest *request = nil;
        [invocation getArgument:&request atIndex:2];
        if (![request.methodName isEqualToString:@"setTags"]) {
            return;
        }
        NSString *application = [request requestDictionary][@"application"];
        [sentApplications addObject:application ?: @""];
        if (sentApplications.count == 2) {
            [secondSend fulfill];
        }
    });

    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"AAAAA-11111" baseUrl:urlA]);

    PWSetTagsRequest *tagsForA = [PWSetTagsRequest new];
    [_requestManager sendTags:tagsForA completion:nil];

    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"BBBBB-22222" baseUrl:urlB]);

    PWSetTagsRequest *tagsForB = [PWSetTagsRequest new];
    [_requestManager sendTags:tagsForB completion:nil];

    [self waitForExpectationsWithTimeout:3 handler:nil];

    XCTAssertEqual(sentApplications.count, 2u);
    XCTAssertEqualObjects(sentApplications[0], @"AAAAA-11111");
    XCTAssertEqualObjects(sentApplications[1], @"BBBBB-22222");
}

/// SDK-882: Verifies that a plain setAppCode: drains the pending setTags window BEFORE the application
/// code moves, so tags accumulated for the previous application carry that application's code — on an
/// install with no active-application record, where nothing is pinned and the body is serialized at
/// send time.
- (void)testSetTagsWindowIsDrainedBeforeThePlainSetterMovesTheApplicationCode {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    XCTAssertFalse([PWPreferences hasActiveApplicationRecord], @"this test is about the legacy install shape");

    [PWPreferences preferences].appCode = @"AAAAA-11111";

    id mockManager = OCMPartialMock(_requestManager);
    _partialManagerMock = mockManager;
    NSMutableArray<NSString *> *sentApplications = [NSMutableArray array];
    OCMStub([mockManager sendRequestInternal:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWRequest *request = nil;
        [invocation getArgument:&request atIndex:2];
        if (![request.methodName isEqualToString:@"setTags"]) {
            return;
        }
        [sentApplications addObject:[request requestDictionary][@"application"] ?: @""];
    });

    [_requestManager sendTags:[PWSetTagsRequest new] completion:nil];

    [PWPreferences preferences].appCode = @"BBBBB-22222";

    XCTAssertEqual(sentApplications.count, 1u, @"the pending window must be sent by the switch, not left to its timer");
    XCTAssertEqualObjects(sentApplications.firstObject, @"AAAAA-11111",
                          @"tags accumulated before the switch must reach the application they were accumulated for");
}

/// SDK-882: Verifies that the timer of an already-drained setTags window does not fire the next window early — it must only send the wrapper it was scheduled for.
- (void)testStaleSetTagsTimerDoesNotTruncateTheNextWindow {
    NSString *urlA = @"https://region-a.example.com/json/1.3/";
    NSString *urlB = @"https://region-b.example.com/json/1.3/";

    id mockManager = OCMPartialMock(_requestManager);
    _partialManagerMock = mockManager;
    NSMutableArray<NSString *> *sentApplications = [NSMutableArray array];
    __block NSDate *secondWindowOpenedAt = nil;
    __block NSTimeInterval secondSendDelay = 0;
    OCMStub([mockManager sendRequestInternal:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWRequest *request = nil;
        [invocation getArgument:&request atIndex:2];
        if (![request.methodName isEqualToString:@"setTags"]) {
            return;
        }
        [sentApplications addObject:[request requestDictionary][@"application"] ?: @""];
        if (sentApplications.count == 2 && secondWindowOpenedAt != nil) {
            secondSendDelay = [[NSDate date] timeIntervalSinceDate:secondWindowOpenedAt];
        }
    });

    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"AAAAA-11111" baseUrl:urlA]);
    [_requestManager sendTags:[PWSetTagsRequest new] completion:nil];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.6]];

    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"BBBBB-22222" baseUrl:urlB]);
    XCTAssertEqual(sentApplications.count, 1u, @"the switch must drain the pending window immediately");

    secondWindowOpenedAt = [NSDate date];
    [_requestManager sendTags:[PWSetTagsRequest new] completion:nil];

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (sentApplications.count < 2 && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }

    XCTAssertEqual(sentApplications.count, 2u);
    XCTAssertEqualObjects(sentApplications[0], @"AAAAA-11111");
    XCTAssertEqualObjects(sentApplications[1], @"BBBBB-22222");
    XCTAssertGreaterThan(secondSendDelay, 0.8,
                         @"the second window was truncated by the first window's stale timer (fired after %.2fs)", secondSendDelay);
}

/// Verifies that a request whose requestDictionary is not JSON-serializable is blocked with an error instead of crashing NSJSONSerialization.
- (void)testNonSerializableRequestDictionary_completesWithErrorInsteadOfCrashing {
    id mockRequest = OCMPartialMock([PWAppOpenRequest new]);
    OCMStub([mockRequest requestDictionary]).andReturn(@{@"bad": [NSDate date]});

    XCTestExpectation *expectation = [self expectationWithDescription:@"blocked"];
    [_requestManager sendRequestInternal:mockRequest completion:^(NSError *error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    [mockRequest stopMocking];
}

@end
