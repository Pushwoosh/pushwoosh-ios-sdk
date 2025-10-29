#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWCachedRequest.h"
#import "PWRequest.h"

@interface PWCachedRequestTest : XCTestCase

@property (nonatomic, strong) id mockRequest;
@property (nonatomic, strong) PWCachedRequest *cachedRequest;

@end

@implementation PWCachedRequestTest

- (void)setUp {
    self.mockRequest = OCMClassMock([PWRequest class]);
    OCMStub([self.mockRequest methodName]).andReturn(@"testMethod");
    OCMStub([self.mockRequest requestDictionary]).andReturn(@{@"key": @"value"});
    OCMStub([self.mockRequest requestIdentifier]).andReturn(@"testIdentifier");

    self.cachedRequest = [[PWCachedRequest alloc] initWithRequest:self.mockRequest];
}

- (void)tearDown {
    [self.mockRequest stopMocking];
    self.mockRequest = nil;
    self.cachedRequest = nil;
}

- (void)testSupportsSecureCoding {
    XCTAssertTrue([PWCachedRequest supportsSecureCoding]);
}

- (void)testInitWithRequest {
    XCTAssertNotNil(self.cachedRequest);
    XCTAssertEqualObjects(self.cachedRequest.methodName, @"testMethod");
    XCTAssertEqualObjects(self.cachedRequest.requestDictionary, @{@"key": @"value"});
    XCTAssertEqualObjects(self.cachedRequest.requestIdentifier, @"testIdentifier");
}

- (void)testInitWithRequestCopiesMethodName {
    id request = OCMClassMock([PWRequest class]);
    OCMStub([request methodName]).andReturn(@"customMethod");
    OCMStub([request requestDictionary]).andReturn(@{});
    OCMStub([request requestIdentifier]).andReturn(@"id");

    PWCachedRequest *cached = [[PWCachedRequest alloc] initWithRequest:request];

    XCTAssertEqualObjects(cached.methodName, @"customMethod");
    [request stopMocking];
}

- (void)testInitWithRequestCopiesRequestDictionary {
    id request = OCMClassMock([PWRequest class]);
    NSDictionary *dict = @{@"param1": @"value1", @"param2": @42};
    OCMStub([request methodName]).andReturn(@"");
    OCMStub([request requestDictionary]).andReturn(dict);
    OCMStub([request requestIdentifier]).andReturn(@"");

    PWCachedRequest *cached = [[PWCachedRequest alloc] initWithRequest:request];

    XCTAssertEqualObjects(cached.requestDictionary, dict);
    [request stopMocking];
}

- (void)testInitWithRequestCopiesRequestIdentifier {
    id request = OCMClassMock([PWRequest class]);
    OCMStub([request methodName]).andReturn(@"");
    OCMStub([request requestDictionary]).andReturn(@{});
    OCMStub([request requestIdentifier]).andReturn(@"uniqueIdentifier123");

    PWCachedRequest *cached = [[PWCachedRequest alloc] initWithRequest:request];

    XCTAssertEqualObjects(cached.requestIdentifier, @"uniqueIdentifier123");
    [request stopMocking];
}

- (void)testInitWithNilMethodName {
    id request = OCMClassMock([PWRequest class]);
    OCMStub([request methodName]).andReturn(nil);
    OCMStub([request requestDictionary]).andReturn(@{});
    OCMStub([request requestIdentifier]).andReturn(@"id");

    PWCachedRequest *cached = [[PWCachedRequest alloc] initWithRequest:request];

    XCTAssertNil(cached.methodName);
    [request stopMocking];
}

- (void)testInitWithNilRequestDictionary {
    id request = OCMClassMock([PWRequest class]);
    OCMStub([request methodName]).andReturn(@"method");
    OCMStub([request requestDictionary]).andReturn(nil);
    OCMStub([request requestIdentifier]).andReturn(@"id");

    PWCachedRequest *cached = [[PWCachedRequest alloc] initWithRequest:request];

    XCTAssertNil(cached.requestDictionary);
    [request stopMocking];
}

- (void)testInitWithNilRequestIdentifier {
    id request = OCMClassMock([PWRequest class]);
    OCMStub([request methodName]).andReturn(@"method");
    OCMStub([request requestDictionary]).andReturn(@{});
    OCMStub([request requestIdentifier]).andReturn(nil);

    PWCachedRequest *cached = [[PWCachedRequest alloc] initWithRequest:request];

    XCTAssertNil(cached.requestIdentifier);
    [request stopMocking];
}

- (void)testInitWithEmptyStrings {
    id request = OCMClassMock([PWRequest class]);
    OCMStub([request methodName]).andReturn(@"");
    OCMStub([request requestDictionary]).andReturn(@{});
    OCMStub([request requestIdentifier]).andReturn(@"");

    PWCachedRequest *cached = [[PWCachedRequest alloc] initWithRequest:request];

    XCTAssertEqualObjects(cached.methodName, @"");
    XCTAssertEqualObjects(cached.requestDictionary, @{});
    XCTAssertEqualObjects(cached.requestIdentifier, @"");
    [request stopMocking];
}

- (void)testInitWithComplexDictionary {
    id request = OCMClassMock([PWRequest class]);
    NSDictionary *complexDict = @{
        @"string": @"text",
        @"number": @123,
        @"bool": @YES,
        @"nested": @{@"inner": @"value"}
    };
    OCMStub([request methodName]).andReturn(@"complexMethod");
    OCMStub([request requestDictionary]).andReturn(complexDict);
    OCMStub([request requestIdentifier]).andReturn(@"complexId");

    PWCachedRequest *cached = [[PWCachedRequest alloc] initWithRequest:request];

    XCTAssertEqualObjects(cached.requestDictionary, complexDict);
    [request stopMocking];
}

@end
