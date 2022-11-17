
#import <XCTest/XCTest.h>

#import "PWPostEventRequest.h"
#import "PWBaseRequestTest.h"

@interface PWPostEventRequestTest : PWBaseRequestTest

@end

@implementation PWPostEventRequestTest

- (void)testMethodName {
    PWPostEventRequest *request = [PWPostEventRequest new];
    XCTAssertEqualObjects([request methodName], @"postEvent");
}

- (void)testPostEvent {
	PWPostEventRequest *request = [PWPostEventRequest new];
	request.event = @"testEvent";
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm";
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    
	request.attributes = @{
		@"testNull" : [NSNull null],
		@"testArray" : @[ @(123), @"qwe", @YES ],
		@"testNumber" : @(42),
		@"testBoolFalse" : @NO,
		@"testBoolTrue" : @YES,
        @"testDate" : [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:1488]]
	};
	
	NSDictionary *requestDict = [request requestDictionary];
	NSDictionary *requestSubdict = @{
		@"event" : requestDict[@"event"],
		@"attributes" : requestDict[@"attributes"]
 	};
	NSDictionary * expectedDict = @{
		@"attributes" :  @{
			@"testArray" : @[ @"123", @"qwe", @"1" ],
			@"testBoolFalse" : @"0",
			@"testBoolTrue" : @"1",
			@"testDate" : @"1970-01-01 00:24",
			@"testNull" : @"null",
			@"testNumber" : @"42",
		},
		@"event" : @"testEvent"
	};
	
	XCTAssertTrue([expectedDict isEqualToDictionary:requestSubdict], @"Error: expected request: (%@) returned request: (%@)", expectedDict, requestSubdict);
}

- (void)testPositiveResponse {
    NSDictionary *response = [self responseFromString:@"{ \"code\" : \"1234-5678\" }"];
    
    PWPostEventRequest *request = [PWPostEventRequest new];
    XCTAssertNil(request.resultCode);
    [request parseResponse:response];
    XCTAssertEqualObjects(request.resultCode , @"1234-5678");
}

- (void)testNoCodeResponse {
    NSDictionary *response = [self responseFromString:@"{ }"];
    
    PWPostEventRequest *request = [PWPostEventRequest new];
    XCTAssertNil(request.resultCode);
    [request parseResponse:response];
    XCTAssertNil(request.resultCode);
}

- (void)testNullCodeResponse {
    NSDictionary *response = [self responseFromString:@"{ \"code\" : null }"];
    
    PWPostEventRequest *request = [PWPostEventRequest new];
    XCTAssertNil(request.resultCode);
    [request parseResponse:response];
    XCTAssertNil(request.resultCode);
}

- (void)testBadCodeTypeResponse {
    NSDictionary *response = [self responseFromString:@"{ \"code\" : [] }"];
    
    PWPostEventRequest *request = [PWPostEventRequest new];
    XCTAssertNil(request.resultCode);
    [request parseResponse:response];
    XCTAssertNil(request.resultCode);
}

@end
