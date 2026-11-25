//
//  PWRequestManagerURLRequestTest.m
//  PushwooshTests
//
//  Created by André Kis
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWRequestManager.h"
#import "PWRequestManager+Internal.h"
#import "PWMessageDeliveryRequest.h"
#import "PWMessageDeliveryRequest+Internal.h"
#import "PWServerCommunicationManager.h"
#import "PWPreferences.h"

@interface PWRequestManager (URLRequestTest)

@property (nonatomic, strong) NSURLSession *session;

- (void)sendRequestInternal:(PWRequest *)request completion:(void (^)(NSError *error))completion;

@end

@interface PWRequestManagerURLRequestTest : XCTestCase

@property (nonatomic) PWRequestManager *requestManager;
@property (nonatomic) id communication;

@end

@implementation PWRequestManagerURLRequestTest

- (void)setUp {
    [super setUp];
    _requestManager = [PWRequestManager new];
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com/pw" headers:@{@"X-Proxy-Key": @"k"}];
    _communication = OCMPartialMock([PWServerCommunicationManager sharedInstance]);
    OCMStub([_communication isServerCommunicationAllowed]).andReturn(YES);
}

- (void)tearDown {
    [_communication stopMocking];
    _requestManager = nil;
    [super tearDown];
}

- (PWMessageDeliveryRequest *)deliveryRequestReceivedAt:(NSDate *)receivedDate {
    PWMessageDeliveryRequest *request = [PWMessageDeliveryRequest new];
    request.pushDict = @{@"p": @"hash-1", @"md": @"meta"};
    request.receivedDate = receivedDate;
    return request;
}

- (PWMessageDeliveryRequest *)deliveryRequest {
    return [self deliveryRequestReceivedAt:nil];
}

/// Verifies the built request is the one the REST transport sends: proxy URL, proxy and SDK headers, wrapped body.
- (void)testURLRequestIsWhatRESTTransportSends {
    id sessionMock = OCMClassMock([NSURLSession class]);
    __block NSURLRequest *sent = nil;
    OCMStub([sessionMock dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSURLRequest *request = nil;
        [invocation getArgument:&request atIndex:2];
        sent = request;
    }).andReturn(OCMClassMock([NSURLSessionDataTask class]));
    _requestManager.session = sessionMock;

    [_requestManager sendRequestInternal:[self deliveryRequest] completion:nil];
    NSURLRequest *built = [_requestManager urlRequestForRequest:[self deliveryRequest] error:nil];

    XCTAssertNotNil(sent);
    XCTAssertEqualObjects(built.URL.absoluteString, @"https://proxy.example.com/pw/messageDeliveryEvent");
    XCTAssertEqualObjects(built.URL, sent.URL);
    XCTAssertEqualObjects(built.HTTPMethod, sent.HTTPMethod);
    XCTAssertEqualObjects(built.allHTTPHeaderFields, sent.allHTTPHeaderFields);
    XCTAssertEqualObjects([built valueForHTTPHeaderField:@"X-Proxy-Key"], @"k");
    XCTAssertTrue([[built valueForHTTPHeaderField:@"Authorization"] hasPrefix:@"Token "]);

    NSDictionary *builtBody = [NSJSONSerialization JSONObjectWithData:built.HTTPBody options:0 error:nil];
    NSDictionary *sentBody = [NSJSONSerialization JSONObjectWithData:sent.HTTPBody options:0 error:nil];
    XCTAssertEqualObjects(builtBody, sentBody);
    XCTAssertEqualObjects(builtBody[@"request"][@"hash"], @"hash-1");
    XCTAssertEqualObjects(builtBody[@"request"][@"metaData"], @"meta");
}

/// Verifies a request whose body does not serialize yields no URL request and an error.
- (void)testURLRequestWithNonSerializableBodyIsNil {
    PWMessageDeliveryRequest *request = [self deliveryRequest];
    request.pushDict = @{@"p": @"hash-1", @"md": [NSDate date]};

    NSError *error = nil;
    XCTAssertNil([_requestManager urlRequestForRequest:request error:&error]);
    XCTAssertNotNil(error);
}

/// Verifies the receive time is serialized as an RFC 3339 UTC string in the JSON body.
- (void)testReceivedAtIsStringInJSONBody {
    NSURLRequest *built = [_requestManager urlRequestForRequest:[self deliveryRequestReceivedAt:[NSDate dateWithTimeIntervalSince1970:1795000000.9]] error:nil];

    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:built.HTTPBody options:0 error:nil];
    XCTAssertEqualObjects(body[@"request"][@"receivedAt"], @"2026-11-18T11:06:40Z");
    XCTAssertNil(body[@"request"][@"timestampUTC"]);
}

/// Verifies the JSON body has no receive time when the request has no receive date.
- (void)testURLRequestWithoutReceivedDateHasNoReceivedAt {
    NSURLRequest *built = [_requestManager urlRequestForRequest:[self deliveryRequest] error:nil];

    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:built.HTTPBody options:0 error:nil];
    XCTAssertNotNil(body[@"request"]);
    XCTAssertNil(body[@"request"][@"receivedAt"]);
    XCTAssertNil(body[@"request"][@"timestampUTC"]);
}

@end
