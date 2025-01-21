
#import "PWAppOpenRequest.h"
#import "PWRequestManager.h"
#import "PWPreferences.h"
#import "PWNetworkModule.h"
#import "PWGDPRManager.h"
#import "PWRequest.h"
#import "PushwooshFramework.h"
#import "PWGetConfigRequest.h"
#import "PWRequestsCacheManager.h"
#import "PWCachedRequest.h"
#import "PWConfig.h"

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import <objc/runtime.h>

@interface PWRequestManager (Test)

@property (nonatomic, strong) NSURLSession *session;

- (NSMutableURLRequest *)prepareRequest:(NSString *)requestUrl jsonRequestData:(NSString *)jsonRequestData;
- (void)sendRequestInternal:(PWRequest *)request completion:(void (^)(NSError *error))completion;
- (void)processResponse:(NSHTTPURLResponse *)httpResponse responseData:(NSData *)responseData request:(PWRequest *)request url:(NSString *)requestUrl requestData:(NSString *)requestData error:(NSError **)outError;
- (BOOL)needToRetry:(NSInteger)statusCode;
- (NSUInteger)increaseRequestCounter:(PWRequest *)request;
- (double)initialTime:(PWRequest *)request;
- (BOOL)isNeedToRetryAfterAppOpenedWith:(PWRequest *)request;
- (NSUInteger)retryCountWith:(PWRequest *)request;
- (NSString *)getApiToken;

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

@end

static id _mockNSBundle;

@implementation PWRequestManagerTest

- (void)setUp {
    [super setUp];
	[[PWNetworkModule module] inject:self];
	
	[NSURLSession setUp];
}

- (void)tearDown {
    [NSURLSession tearDown];
	[PWPreferences preferences].baseUrl = [[PWPreferences preferences] defaultBaseUrl];
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

- (void)testPushwooshApiTokenAvailable {
    NSString *pushwooshApiToken = @"qwertyuiopasdfghjklzxcvbnm_new";
    id mockNSBundle = OCMPartialMock([PWConfig config]);
    OCMStub([mockNSBundle pushwooshApiToken]).andReturn(pushwooshApiToken);
    
    [_requestManager getApiToken];
    
    XCTAssertEqual(pushwooshApiToken, [_requestManager getApiToken]);
}

- (void)testPwApiTokenAvailable {
    NSString *pwApiToken = @"qwertyuiopasdfghjklzxcvbnm_old";
    id mockNSBundle = OCMPartialMock([PWConfig config]);
    OCMStub([mockNSBundle apiToken]).andReturn(pwApiToken);
    
    [_requestManager getApiToken];
    
    XCTAssertEqual(pwApiToken, [_requestManager getApiToken]);
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

- (void)testCacheFailedRequest {
    NSString *methodName = @"applicationOpen";
    NSInteger statusCode = 500;
    PWRequest *request = [[PWRequest alloc] init];
    id mockPWRequestsCacheManager = OCMPartialMock([PWRequestsCacheManager sharedInstance]);
    id mockRequest = OCMPartialMock(request);
    OCMStub([mockRequest methodName]).andReturn(methodName);
    OCMStub([mockRequest requestDictionary]).andReturn(@{});
    id mockSession = OCMPartialMock(_requestManager.session);
    __block NSURLResponse *response = [[NSURLResponse alloc] init];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    id mockHTTPResponse = OCMPartialMock(httpResponse);
    OCMStub([mockSession dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void(^handler)(NSData *data, NSURLResponse *response, NSError *error);
        [invocation getArgument:&handler atIndex:3];
        handler(nil, response, nil);
    });
    OCMStub([mockHTTPResponse statusCode]).andReturn(statusCode);
    OCMStub([mockRequest cacheable]).andReturn(YES);
    OCMExpect([mockPWRequestsCacheManager cacheRequest:OCMOCK_ANY]);
    
    [_requestManager sendRequestInternal:request completion:^(NSError *error) {}];
    
    OCMVerifyAll(mockPWRequestsCacheManager);
}

- (void)testRequestDeletedAfterSuccessRetry {
    NSInteger statusCode = 200;
    double delay = 10.f;
    double currentTime = 1000.f;
    NSString *methodName = @"applicationOpen";
    PWCachedRequest *cachedRequest = [[PWCachedRequest alloc] init];
    id mockCachedRequest = OCMPartialMock(cachedRequest);
    OCMStub([mockCachedRequest methodName]).andReturn(methodName);
    OCMStub([mockCachedRequest requestDictionary]).andReturn(cachedRequest.baseDictionary);
    id mockNSUserDefaults = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    OCMStub([mockNSUserDefaults doubleForKey:OCMOCK_ANY]).andReturn(delay);
    id mockNSDate = OCMClassMock([NSDate class]);
    OCMStub([mockNSDate date]).andReturn(mockNSDate);
    OCMStub([mockNSDate timeIntervalSince1970]).andReturn(currentTime);
    id mockSession = OCMPartialMock(_requestManager.session);
    __block NSURLResponse *response = [[NSURLResponse alloc] init];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    id mockHTTPResponse = OCMPartialMock(httpResponse);
    OCMStub([mockSession dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void(^handler)(NSData *data, NSURLResponse *response, NSError *error);
        [invocation getArgument:&handler atIndex:3];
        handler(nil, response, nil);
    });
    OCMStub([mockHTTPResponse statusCode]).andReturn(statusCode);
    id mockPWRequestsCacheManager = OCMPartialMock([PWRequestsCacheManager sharedInstance]);
    OCMExpect([mockPWRequestsCacheManager deleteCachedRequest:cachedRequest]);
    
    [_requestManager sendRequestInternal:cachedRequest completion:^(NSError *error) {}];
    
    OCMVerifyAll(mockPWRequestsCacheManager);
}

- (void)testIncreaseRetryCount {
    NSInteger statusCode = 500;
    NSString *methodName = @"applicationOpen";
    id mockPWRequestManager = OCMPartialMock(self.requestManager);
    OCMStub([mockPWRequestManager isNeedToRetryAfterAppOpenedWith:OCMOCK_ANY]).andReturn(YES);
    PWCachedRequest *cachedRequest = [[PWCachedRequest alloc] init];
    id mockCachedRequest = OCMPartialMock(cachedRequest);
    OCMStub([mockCachedRequest methodName]).andReturn(methodName);
    OCMStub([mockCachedRequest requestDictionary]).andReturn(cachedRequest.baseDictionary);
    id mockSession = OCMPartialMock(_requestManager.session);
    __block NSURLResponse *response = [[NSURLResponse alloc] init];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    id mockHTTPResponse = OCMPartialMock(httpResponse);
    OCMStub([mockSession dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        void(^handler)(NSData *data, NSURLResponse *response, NSError *error);
        [invocation getArgument:&handler atIndex:3];
        handler(nil, response, nil);
    });
    OCMStub([mockHTTPResponse statusCode]).andReturn(statusCode);
    OCMStub([mockPWRequestManager retryCountWith:OCMOCK_ANY]).andReturn(2);
    OCMExpect([mockPWRequestManager increaseRequestCounter:OCMOCK_ANY]);
    
    [_requestManager sendRequestInternal:cachedRequest completion:^(NSError *error) {}];
    
    OCMVerify([mockPWRequestManager increaseRequestCounter:OCMOCK_ANY]);
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
    
    OCMVerify([mockNSMutableURLRequest addValue:correctFormat forHTTPHeaderField:@"Authorization"]);
}

- (void)testCheckCurrectCulculateDelay {
    double remainTime = 5.f;
    PWCachedRequest *cachedRequest = [[PWCachedRequest alloc] init];
    id mockNSUserDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockNSUserDefaults standardUserDefaults]).andReturn(mockNSUserDefaults);
    OCMStub([mockNSUserDefaults doubleForKey:OCMOCK_ANY]).andReturn(5);
    id mockNSDate = OCMClassMock([NSDate class]);
    OCMStub([mockNSDate date]).andReturn(mockNSDate);
    OCMStub([mockNSDate timeIntervalSince1970]).andReturn(5);
    
    [_requestManager sendRequestInternal:cachedRequest completion:^(NSError *error) {}];
    
    XCTAssertEqual(remainTime, [_requestManager initialTime:cachedRequest]);
}

@end
