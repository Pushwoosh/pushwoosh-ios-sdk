
#import <XCTest/XCTest.h>

#import "PWGetNearestZoneRequest.h"
#import "PWGeozone.h"
#import "PWBaseRequestTest.h"

@interface PWGetNearestZoneRequestTest : PWBaseRequestTest

@end

@implementation PWGetNearestZoneRequestTest

- (void)testMethodName {
	PWGetNearestZoneRequest *request = [PWGetNearestZoneRequest new];
	XCTAssertEqualObjects([request methodName], @"getNearestZone");
}

- (void)testNoGeozonesResponse {
    NSDictionary *response = [self responseFromString:@"{ }"];

	PWGetNearestZoneRequest *request = [PWGetNearestZoneRequest new];
	XCTAssertNil(request.nearestGeozones);
	[request parseResponse:response];
	[self assertNilOrEmpty:request.nearestGeozones];
}

- (void)testBadGeozonesTypeResponse {
    NSDictionary *response = [self responseFromString:@"{ \"geozones\":\"fail\" }"];
	
	PWGetNearestZoneRequest *request = [PWGetNearestZoneRequest new];
	XCTAssertNil(request.nearestGeozones);
	[request parseResponse:response];
	[self assertNilOrEmpty:request.nearestGeozones];
}

- (void)testRequestDictionary {
	PWGetNearestZoneRequest *request = [PWGetNearestZoneRequest new];
	CLLocationCoordinate2D coordinate;
	coordinate.latitude = 12.3;
	coordinate.longitude = 45.6;
	
	request.userCoordinate = coordinate;
	
	NSDictionary *requestDict = [request requestDictionary];
	
	XCTAssertNotNil(requestDict);
	XCTAssertEqualWithAccuracy([requestDict[@"lat"] doubleValue], 12.3, 0.01);
	XCTAssertEqualWithAccuracy([requestDict[@"lng"] doubleValue], 45.6, 0.01);
	XCTAssertEqual([requestDict[@"more"] integerValue], 1);
}

- (void)assertNilOrEmpty:(NSArray*)array {
	if (array) {
		XCTAssertTrue([array isKindOfClass:[NSArray class]]);
	}
	XCTAssertTrue(array == nil || [array count] == 0);
}

@end
