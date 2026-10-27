#import <XCTest/XCTest.h>

#import "PWGetResourcesRequest.h"
#import "PWResource.h"
#import "PWBaseRequestTest.h"

@interface PWGetResourcesRequestTest : PWBaseRequestTest

@end

@implementation PWGetResourcesRequestTest

- (void)testMethodName {
	PWGetResourcesRequest *request = [PWGetResourcesRequest new];
	XCTAssertEqualObjects([request methodName], @"getInApps");
}

- (void)testPositiveResponse {
    NSDictionary *response = [self responseFromString:@"{\"inApps\":[{\"url\":\"https:\\/\\/inapp.pushwoosh.com\\/json\\/1.3\\/getInApp\\/FE293-BA62E-1\",\"code\":\"FE293-BA62E\",\"layout\":\"topbanner\",\"updated\":1465292957,\"closeButtonType\":\"1\"}]}"];

	PWGetResourcesRequest *request = [PWGetResourcesRequest new];

	XCTAssertNil(request.resources);
	[request parseResponse:response];

	NSDictionary *inapps = request.resources;

	XCTAssertEqual([inapps count], 1);

	PWResource *resource = inapps[@"FE293-BA62E"];
	XCTAssertEqualObjects(resource.code, @"FE293-BA62E");
	XCTAssertEqualObjects(resource.url, @"https://inapp.pushwoosh.com/json/1.3/getInApp/FE293-BA62E-1");
	XCTAssertEqual(resource.updated, 1465292957);
	XCTAssertEqual(resource.closeButton, YES);
}

/// Verifies that a response without inApps leaves resources nil, so the cached catalog is not replaced.
- (void)testNoInApps {
    NSDictionary *response = [self responseFromString:@"{ }"];

	PWGetResourcesRequest *request = [PWGetResourcesRequest new];
	[request parseResponse:response];

	XCTAssertNil(request.resources);
}

/// Verifies that a null inApps leaves resources nil, so the cached catalog is not replaced.
- (void)testNullInApps {
    NSDictionary *response = [self responseFromString:@"{ \"inApps\":null }"];

	PWGetResourcesRequest *request = [PWGetResourcesRequest new];
	[request parseResponse:response];

	XCTAssertNil(request.resources);
}

/// Verifies that inApps of a non-array type leaves resources nil, so the cached catalog is not replaced.
- (void)testInAppsNotArray {
    NSDictionary *response = [self responseFromString:@"{ \"inApps\":\"FE293-BA62E\" }"];

	PWGetResourcesRequest *request = [PWGetResourcesRequest new];
	[request parseResponse:response];

	XCTAssertNil(request.resources);
}

/// Verifies that an empty inApps list yields an empty catalog, which clears the cache as before.
- (void)testEmptyInApps {
    NSDictionary *response = [self responseFromString:@"{ \"inApps\":[] }"];

	PWGetResourcesRequest *request = [PWGetResourcesRequest new];
	[request parseResponse:response];

	XCTAssertNotNil(request.resources);
	XCTAssertEqual(request.resources.count, 0u);
}

@end
