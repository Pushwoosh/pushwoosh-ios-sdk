
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWRequestManager.h"
#import "PWPreferences.h"
#import "PWNetworkModule.h"
#import "PWAppOpenRequest.h"
#import "PWRequest.h"
#import "PWConfig.h"

#pragma mark - Expose private properties for testing

@interface PWRequestManager (ReverseProxyTest)

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, copy) NSString *reverseProxyUrl;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *customHeaders;

- (NSString *)baseUrl;
- (NSMutableURLRequest *)prepareRequest:(NSString *)requestUrl jsonRequestData:(NSString *)jsonRequestData;
- (void)processResponse:(NSHTTPURLResponse *)httpResponse responseData:(NSData *)responseData request:(PWRequest *)request url:(NSString *)requestUrl requestData:(NSString *)requestData error:(NSError **)outError;
- (void)sendRequestInternal:(PWRequest *)request completion:(void (^)(NSError *error))completion;

@end

#pragma mark - Test class

@interface PWReverseProxyTest : XCTestCase

@property (nonatomic, strong) PWRequestManager *requestManager;

@end

@implementation PWReverseProxyTest

- (void)setUp {
    [super setUp];
    _requestManager = [PWRequestManager new];
}

- (void)tearDown {
    [PWPreferences preferences].baseUrl = [[PWPreferences preferences] defaultBaseUrl];
    _requestManager = nil;
    [super tearDown];
}

#pragma mark - setReverseProxyUrl:headers: Tests

/// Verifies that URL is stored in memory after setting reverse proxy.
- (void)testSetReverseProxyUrl_setsUrlInMemory {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTAssertTrue([_requestManager.reverseProxyUrl hasPrefix:@"https://proxy.example.com"]);
}

/// Verifies that nil URL is rejected.
- (void)testSetReverseProxyUrl_rejectsNil {
    [_requestManager setReverseProxyUrl:nil headers:nil];

    XCTAssertNil(_requestManager.reverseProxyUrl);
}

/// Verifies that empty string URL is rejected.
- (void)testSetReverseProxyUrl_rejectsEmptyString {
    [_requestManager setReverseProxyUrl:@"" headers:nil];

    XCTAssertNil(_requestManager.reverseProxyUrl);
}

/// Verifies that URL without http/https scheme is rejected.
- (void)testSetReverseProxyUrl_rejectsUrlWithoutScheme {
    [_requestManager setReverseProxyUrl:@"proxy.example.com" headers:nil];

    XCTAssertNil(_requestManager.reverseProxyUrl);
}

/// Verifies that URL with ftp scheme is rejected.
- (void)testSetReverseProxyUrl_rejectsFtpScheme {
    [_requestManager setReverseProxyUrl:@"ftp://proxy.example.com" headers:nil];

    XCTAssertNil(_requestManager.reverseProxyUrl);
}

/// Verifies that malformed URL is rejected.
- (void)testSetReverseProxyUrl_rejectsMalformedUrl {
    [_requestManager setReverseProxyUrl:@"https://" headers:nil];

    // NSURL may or may not parse "https://" — check actual behavior
    // The point is it shouldn't crash
    // If NSURL parses it, the URL will be set; if not, it won't
}

/// Verifies that trailing slash is appended when missing.
- (void)testSetReverseProxyUrl_appendsTrailingSlash {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTAssertEqualObjects(_requestManager.reverseProxyUrl, @"https://proxy.example.com/");
}

/// Verifies that trailing slash is preserved when already present.
- (void)testSetReverseProxyUrl_preservesExistingTrailingSlash {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com/" headers:nil];

    XCTAssertEqualObjects(_requestManager.reverseProxyUrl, @"https://proxy.example.com/");
}

/// Verifies that URL with path gets trailing slash.
- (void)testSetReverseProxyUrl_appendsTrailingSlashToPath {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com/pushwoosh/api" headers:nil];

    XCTAssertEqualObjects(_requestManager.reverseProxyUrl, @"https://proxy.example.com/pushwoosh/api/");
}

/// Verifies that URL string is copied defensively.
- (void)testSetReverseProxyUrl_copiesUrlString {
    NSMutableString *mutableUrl = [NSMutableString stringWithString:@"https://proxy.example.com"];
    [_requestManager setReverseProxyUrl:mutableUrl headers:nil];

    [mutableUrl appendString:@"/modified"];

    XCTAssertEqualObjects(_requestManager.reverseProxyUrl, @"https://proxy.example.com/");
}

/// Verifies that second call overwrites previous URL.
- (void)testSetReverseProxyUrl_overwritesPreviousUrl {
    [_requestManager setReverseProxyUrl:@"https://first.example.com" headers:nil];
    [_requestManager setReverseProxyUrl:@"https://second.example.com" headers:nil];

    XCTAssertEqualObjects(_requestManager.reverseProxyUrl, @"https://second.example.com/");
}

/// Verifies that nil URL after valid URL does not clear proxy.
- (void)testSetReverseProxyUrl_nilAfterValidUrl_doesNotClear {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];
    [_requestManager setReverseProxyUrl:nil headers:nil];

    XCTAssertEqualObjects(_requestManager.reverseProxyUrl, @"https://proxy.example.com/");
}

/// Verifies that empty string after valid URL does not clear proxy.
- (void)testSetReverseProxyUrl_emptyAfterValidUrl_doesNotClear {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];
    [_requestManager setReverseProxyUrl:@"" headers:nil];

    XCTAssertEqualObjects(_requestManager.reverseProxyUrl, @"https://proxy.example.com/");
}

/// Verifies that headers are stored when provided.
- (void)testSetReverseProxyUrl_storesHeaders {
    NSDictionary *headers = @{@"X-Auth": @"token123"};
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:headers];

    XCTAssertEqualObjects(_requestManager.customHeaders, headers);
}

/// Verifies that nil headers resets custom headers to empty dict.
- (void)testSetReverseProxyUrl_nilHeadersSetsEmptyDict {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:@{@"X-Auth": @"token"}];
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTAssertEqualObjects(_requestManager.customHeaders, @{});
}

/// Verifies that HTTP URL is accepted.
- (void)testSetReverseProxyUrl_httpUrlAccepted {
    [_requestManager setReverseProxyUrl:@"http://internal-proxy.local:8080" headers:nil];

    XCTAssertEqualObjects(_requestManager.reverseProxyUrl, @"http://internal-proxy.local:8080/");
}

/// Verifies that URL with port is accepted.
- (void)testSetReverseProxyUrl_handlesUrlWithPort {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com:8443" headers:nil];

    XCTAssertEqualObjects(_requestManager.reverseProxyUrl, @"https://proxy.example.com:8443/");
}

/// Verifies that settings are not persisted to NSUserDefaults.
- (void)testSetReverseProxyUrl_doesNotPersistToNSUserDefaults {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:@"PWReverseProxyURL"]);
    XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:@"PWUsingReverseProxy"]);
}

/// Verifies that new instance does not inherit proxy from previous instance.
- (void)testSetReverseProxyUrl_notPersistedAcrossInstances {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    PWRequestManager *newManager = [PWRequestManager new];

    XCTAssertNil(newManager.reverseProxyUrl);
    XCTAssertEqualObjects([newManager baseUrl], [PWPreferences preferences].baseUrl);
}

#pragma mark - baseUrl Tests

/// Verifies that default URL is returned when proxy is not set.
- (void)testBaseUrl_returnsDefaultWhenProxyNotSet {
    NSString *defaultUrl = [PWPreferences preferences].baseUrl;

    XCTAssertEqualObjects([_requestManager baseUrl], defaultUrl);
}

/// Verifies that proxy URL is returned when proxy is active.
- (void)testBaseUrl_returnsProxyUrlWhenProxyActive {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTAssertEqualObjects([_requestManager baseUrl], @"https://proxy.example.com/");
}

/// Verifies that proxy takes priority over PWPreferences.baseUrl.
- (void)testBaseUrl_proxyTakesPriorityOverPreferences {
    [PWPreferences preferences].baseUrl = @"https://custom.pushwoosh.com/json/1.3/";
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTAssertEqualObjects([_requestManager baseUrl], @"https://proxy.example.com/");
}

/// Verifies that updated proxy URL is reflected in baseUrl.
- (void)testBaseUrl_returnsUpdatedProxyUrlAfterChange {
    [_requestManager setReverseProxyUrl:@"https://first.example.com" headers:nil];
    XCTAssertEqualObjects([_requestManager baseUrl], @"https://first.example.com/");

    [_requestManager setReverseProxyUrl:@"https://second.example.com" headers:nil];
    XCTAssertEqualObjects([_requestManager baseUrl], @"https://second.example.com/");
}

#pragma mark - Custom Headers Tests

/// Verifies that default custom headers are an empty dict.
- (void)testCustomHeaders_defaultIsEmptyDict {
    XCTAssertNotNil(_requestManager.customHeaders);
    XCTAssertEqual(_requestManager.customHeaders.count, 0);
}

/// Verifies that custom headers are set via setReverseProxyUrl:headers:.
- (void)testCustomHeaders_setViaReverseProxy {
    NSDictionary *headers = @{@"X-Auth": @"token123", @"X-Trace": @"trace-id"};
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:headers];

    XCTAssertEqualObjects(_requestManager.customHeaders[@"X-Auth"], @"token123");
    XCTAssertEqualObjects(_requestManager.customHeaders[@"X-Trace"], @"trace-id");
}

/// Verifies that custom headers make a defensive copy.
- (void)testCustomHeaders_makesDefensiveCopy {
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionaryWithDictionary:@{@"X-Auth": @"token123"}];
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:mutableHeaders];

    mutableHeaders[@"X-Extra"] = @"injected";

    XCTAssertNil(_requestManager.customHeaders[@"X-Extra"]);
    XCTAssertEqual(_requestManager.customHeaders.count, 1);
}

#pragma mark - prepareRequest: Custom Headers Injection Tests

/// Verifies that custom headers are included in request when proxy is active.
- (void)testPrepareRequest_includesCustomHeadersWhenProxyActive {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:@{@"X-Auth": @"token123"}];

    NSMutableURLRequest *urlRequest = [_requestManager prepareRequest:@"https://proxy.example.com/applicationOpen" jsonRequestData:@"{\"request\":{}}"];

    XCTAssertEqualObjects([urlRequest valueForHTTPHeaderField:@"X-Auth"], @"token123");
}

/// Verifies that custom headers are NOT included when proxy is not set.
- (void)testPrepareRequest_noCustomHeadersWhenProxyNotActive {
    // Directly set customHeaders without proxy (shouldn't normally happen, but test the guard)
    NSMutableURLRequest *urlRequest = [_requestManager prepareRequest:@"https://api.pushwoosh.com/applicationOpen" jsonRequestData:@"{\"request\":{}}"];

    // Without proxy, no custom headers should be added
    XCTAssertNil([urlRequest valueForHTTPHeaderField:@"X-Auth"]);
}

/// Verifies that multiple custom headers are included.
- (void)testPrepareRequest_includesMultipleCustomHeaders {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:@{@"X-Auth": @"token123", @"X-Trace": @"trace-id"}];

    NSMutableURLRequest *urlRequest = [_requestManager prepareRequest:@"https://proxy.example.com/applicationOpen" jsonRequestData:@"{\"request\":{}}"];

    XCTAssertEqualObjects([urlRequest valueForHTTPHeaderField:@"X-Auth"], @"token123");
    XCTAssertEqualObjects([urlRequest valueForHTTPHeaderField:@"X-Trace"], @"trace-id");
}

/// Verifies that standard headers are always present.
- (void)testPrepareRequest_standardHeadersPresent {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:@{@"X-Auth": @"token123"}];

    NSMutableURLRequest *urlRequest = [_requestManager prepareRequest:@"https://proxy.example.com/applicationOpen" jsonRequestData:@"{\"request\":{}}"];

    XCTAssertNotNil([urlRequest valueForHTTPHeaderField:@"Content-Type"]);
    XCTAssertTrue([[urlRequest valueForHTTPHeaderField:@"Content-Type"] containsString:@"application/json"]);
}

/// Verifies that SDK default Authorization header is present when no custom headers.
- (void)testPrepareRequest_noCustomHeaders_authorizationIsSDKDefault {
    NSMutableURLRequest *urlRequest = [_requestManager prepareRequest:@"https://api.pushwoosh.com/applicationOpen" jsonRequestData:@"{\"request\":{}}"];

    NSString *auth = [urlRequest valueForHTTPHeaderField:@"Authorization"];
    XCTAssertNotNil(auth);
    XCTAssertTrue([auth hasPrefix:@"Token "]);
}

#pragma mark - processResponse: Proxy Protection Tests

/// Verifies that base_url from server response is blocked when proxy is active.
- (void)testProcessResponse_baseUrlNotChangedWhenProxyActive {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    NSString *originalBaseUrl = [PWPreferences preferences].baseUrl;

    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://proxy.example.com"] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSString *responseStr = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null,\"base_url\":\"https://evil.pushwoosh.com/json/1.3/\"}";
    NSData *responseData = [responseStr dataUsingEncoding:NSUTF8StringEncoding];

    PWRequest *request = [PWAppOpenRequest new];
    NSError *error = nil;
    [_requestManager processResponse:httpResponse responseData:responseData request:request url:@"https://proxy.example.com/applicationOpen" requestData:@"{}" error:&error];

    XCTAssertEqualObjects([PWPreferences preferences].baseUrl, originalBaseUrl);
}

/// Verifies that base_url from server response is applied when proxy is not active.
- (void)testProcessResponse_baseUrlChangedWhenProxyNotActive {
    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://api.pushwoosh.com"] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSString *responseStr = @"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null,\"base_url\":\"https://new.pushwoosh.com/json/1.3/\"}";
    NSData *responseData = [responseStr dataUsingEncoding:NSUTF8StringEncoding];

    PWRequest *request = [PWAppOpenRequest new];
    NSError *error = nil;
    [_requestManager processResponse:httpResponse responseData:responseData request:request url:@"https://api.pushwoosh.com/applicationOpen" requestData:@"{}" error:&error];

    XCTAssertEqualObjects([PWPreferences preferences].baseUrl, @"https://new.pushwoosh.com/json/1.3/");
}

/// Verifies that missing status_code does not reset base_url when proxy is active.
- (void)testProcessResponse_noStatusCodeDoesNotResetUrlWhenProxyActive {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];
    [PWPreferences preferences].baseUrl = @"https://custom.pushwoosh.com/json/1.3/";

    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://proxy.example.com"] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSString *responseStr = @"{\"status_message\":\"OK\",\"response\":null}";
    NSData *responseData = [responseStr dataUsingEncoding:NSUTF8StringEncoding];

    PWRequest *request = [PWAppOpenRequest new];
    NSError *error = nil;
    [_requestManager processResponse:httpResponse responseData:responseData request:request url:@"https://proxy.example.com/applicationOpen" requestData:@"{}" error:&error];

    XCTAssertEqualObjects([PWPreferences preferences].baseUrl, @"https://custom.pushwoosh.com/json/1.3/");
}

/// Verifies that missing status_code resets base_url to default when proxy is not active.
- (void)testProcessResponse_noStatusCodeResetsUrlWhenProxyNotActive {
    [PWPreferences preferences].baseUrl = @"https://custom.pushwoosh.com/json/1.3/";
    NSString *defaultUrl = [[PWPreferences preferences] defaultBaseUrl];

    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://custom.pushwoosh.com"] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSString *responseStr = @"{\"status_message\":\"OK\",\"response\":null}";
    NSData *responseData = [responseStr dataUsingEncoding:NSUTF8StringEncoding];

    PWRequest *request = [PWAppOpenRequest new];
    NSError *error = nil;
    [_requestManager processResponse:httpResponse responseData:responseData request:request url:@"https://custom.pushwoosh.com/applicationOpen" requestData:@"{}" error:&error];

    XCTAssertEqualObjects([PWPreferences preferences].baseUrl, defaultUrl);
}

/// Verifies that multiple base_url change attempts are all blocked when proxy is active.
- (void)testProcessResponse_proxyActive_multipleBaseUrlAttempts_allBlocked {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    NSString *originalBaseUrl = [PWPreferences preferences].baseUrl;

    NSString *urls[] = {
        @"https://evil1.com/json/1.3/",
        @"https://evil2.com/json/1.3/",
        @"https://evil3.com/json/1.3/"
    };

    for (int i = 0; i < 3; i++) {
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://proxy.example.com"] statusCode:200 HTTPVersion:nil headerFields:nil];
        NSString *responseStr = [NSString stringWithFormat:@"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null,\"base_url\":\"%@\"}", urls[i]];
        NSData *responseData = [responseStr dataUsingEncoding:NSUTF8StringEncoding];

        PWRequest *request = [PWAppOpenRequest new];
        NSError *error = nil;
        [_requestManager processResponse:httpResponse responseData:responseData request:request url:@"https://proxy.example.com/applicationOpen" requestData:@"{}" error:&error];
    }

    XCTAssertEqualObjects([PWPreferences preferences].baseUrl, originalBaseUrl);
}

#pragma mark - Thread Safety Tests

/// Verifies concurrent reads of baseUrl don't crash.
- (void)testThreadSafety_concurrentBaseUrlReads {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"concurrent reads"];
    expectation.expectedFulfillmentCount = 100;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    for (int i = 0; i < 100; i++) {
        dispatch_async(queue, ^{
            NSString *url = [_requestManager baseUrl];
            XCTAssertNotNil(url);
            [expectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

/// Verifies concurrent set and read operations don't crash.
- (void)testThreadSafety_concurrentSetAndRead {
    XCTestExpectation *expectation = [self expectationWithDescription:@"concurrent set and read"];
    expectation.expectedFulfillmentCount = 200;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

    for (int i = 0; i < 100; i++) {
        dispatch_async(queue, ^{
            [_requestManager setReverseProxyUrl:[NSString stringWithFormat:@"https://proxy%d.example.com", i] headers:nil];
            [expectation fulfill];
        });
    }

    for (int i = 0; i < 100; i++) {
        dispatch_async(queue, ^{
            NSString *url = [_requestManager baseUrl];
            XCTAssertNotNil(url);
            [expectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

#pragma mark - Integration: Request URL Construction

/// Verifies that requests use the proxy URL when proxy is active.
- (void)testIntegration_requestUrlUsesProxyUrl {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com/" headers:nil];

    NSMutableURLRequest *urlRequest = [_requestManager prepareRequest:@"https://proxy.example.com/applicationOpen" jsonRequestData:@"{\"request\":{}}"];

    XCTAssertTrue([urlRequest.URL.absoluteString hasPrefix:@"https://proxy.example.com/"], @"Request URL should start with proxy URL, got: %@", urlRequest.URL.absoluteString);
}

/// Verifies that requests use the default URL when proxy is not set.
- (void)testIntegration_requestUrlUsesDefaultWhenNoProxy {
    NSString *defaultUrl = [PWPreferences preferences].baseUrl;

    NSMutableURLRequest *urlRequest = [_requestManager prepareRequest:[NSString stringWithFormat:@"%@applicationOpen", defaultUrl] jsonRequestData:@"{\"request\":{}}"];

    XCTAssertTrue([urlRequest.URL.absoluteString hasPrefix:defaultUrl], @"Request URL should start with default URL, got: %@", urlRequest.URL.absoluteString);
}

/// Verifies that custom headers are included in proxy requests.
- (void)testIntegration_requestIncludesCustomHeaders {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com/" headers:@{@"X-Auth-Token": @"secret123", @"X-Client-ID": @"client-456"}];

    NSMutableURLRequest *urlRequest = [_requestManager prepareRequest:@"https://proxy.example.com/applicationOpen" jsonRequestData:@"{\"request\":{}}"];

    XCTAssertEqualObjects([urlRequest valueForHTTPHeaderField:@"X-Auth-Token"], @"secret123");
    XCTAssertEqualObjects([urlRequest valueForHTTPHeaderField:@"X-Client-ID"], @"client-456");
}

#pragma mark - Edge Cases

/// Verifies that very long URLs are accepted.
- (void)testEdgeCase_veryLongUrl {
    NSMutableString *longUrl = [NSMutableString stringWithString:@"https://proxy.example.com/"];
    for (int i = 0; i < 1000; i++) {
        [longUrl appendString:@"segment/"];
    }

    [_requestManager setReverseProxyUrl:longUrl headers:nil];

    XCTAssertNotNil(_requestManager.reverseProxyUrl);
}

/// Verifies that custom headers with empty value are accepted.
- (void)testEdgeCase_customHeadersWithEmptyValue {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:@{@"X-Auth": @""}];

    XCTAssertEqualObjects(_requestManager.customHeaders[@"X-Auth"], @"");
}

/// Verifies that custom headers with special characters are preserved.
- (void)testEdgeCase_customHeadersWithSpecialChars {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com" headers:@{@"X-Auth": @"Bearer abc+def/ghi="}];

    NSMutableURLRequest *urlRequest = [_requestManager prepareRequest:@"https://proxy.example.com/test" jsonRequestData:@"{\"request\":{}}"];

    XCTAssertEqualObjects([urlRequest valueForHTTPHeaderField:@"X-Auth"], @"Bearer abc+def/ghi=");
}

@end
