
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

- (void)testNoInApps {
    NSDictionary *response = [self responseFromString:@"{ }"];
	
	PWGetResourcesRequest *request = [PWGetResourcesRequest new];
	
	XCTAssertNil(request.resources);
	[request parseResponse:response];

	[self assertNilOrEmpty:request.resources];
}

- (void)testNullInApps {
    NSDictionary *response = [self responseFromString:@"{ \"inApps\":null }"];
	
	PWGetResourcesRequest *request = [PWGetResourcesRequest new];
	
	XCTAssertNil(request.resources);
	[request parseResponse:response];
	
	[self assertNilOrEmpty:request.resources];
}

- (void)testEmptyInApps {
    NSDictionary *response = [self responseFromString:@"{ \"inApps\":[] }"];
	
	PWGetResourcesRequest *request = [PWGetResourcesRequest new];
	
	XCTAssertNil(request.resources);
	[request parseResponse:response];
	
	[self assertNilOrEmpty:request.resources];
}

- (void)assertNilOrEmpty:(NSDictionary*)dict {
	if (dict) {
		XCTAssertTrue([dict isKindOfClass:[NSDictionary class]]);
	}
	XCTAssertTrue(dict == nil || [dict count] == 0);
}

@end
