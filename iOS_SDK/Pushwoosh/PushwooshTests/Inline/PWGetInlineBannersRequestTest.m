//
//  PWGetInlineBannersRequestTest.m
//  PushwooshTests
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWGetInlineBannersRequest.h"
#import "PWRequest+Internal.h"
#import "PWConfig.h"
#import "PWNetworkModule.h"
#import "PWRequestManager.h"
#import "PWPreferences.h"

@interface PWGetInlineBannersRequestTest : XCTestCase

@property (nonatomic, strong) id configMock;
@property (nonatomic, strong) id requestManagerMock;

@end

@implementation PWGetInlineBannersRequestTest

- (void)setUp {
    [super setUp];
    _configMock = OCMPartialMock([PWConfig config]);
    OCMStub([_configMock inlineUrl]).andReturn(nil);
    _requestManagerMock = OCMPartialMock([PWNetworkModule module].requestManager);
}

- (void)tearDown {
    [_requestManagerMock stopMocking];
    [_configMock stopMocking];
    [super tearDown];
}

- (PWGetInlineBannersRequest *)homeRequest {
    return [[PWGetInlineBannersRequest alloc] initWithSlots:@[@"home_top", @"cart_bottom"] formats:@[@"native"]];
}

/// Verifies that the request goes to Pushwoosh_INLINE_URL from Info.plist, with the trailing slash added.
- (void)testUsesInlineUrlFromInfoPlist {
    [_configMock stopMocking];
    _configMock = OCMPartialMock([PWConfig config]);
    OCMStub([_configMock inlineUrl]).andReturn(@"http://127.0.0.1:8085/api");
    PWGetInlineBannersRequest *request = [self homeRequest];
    request.pinnedBaseUrl = @"https://ABCDE-12345.api.pushwoosh.com/json/1.3/";

    XCTAssertEqualObjects([request baseUrl], @"http://127.0.0.1:8085/api/");
}

/// Verifies that without Pushwoosh_INLINE_URL the request goes to the device API next to the SDK base URL.
- (void)testFallsBackToDeviceApiNextToBaseUrl {
    PWGetInlineBannersRequest *request = [self homeRequest];
    request.pinnedBaseUrl = @"https://ABCDE-12345.api.pushwoosh.com/json/1.3/";

    XCTAssertEqualObjects([request baseUrl], @"https://ABCDE-12345.api.pushwoosh.com/api/v2/device-api/");
}

/// Verifies that a reverse proxy without json/1.3/ leaves the request without an endpoint.
- (void)testReverseProxyWithoutLegacyPathHasNoEndpoint {
    OCMStub([_requestManagerMock isUsingReverseProxy]).andReturn(YES);
    PWGetInlineBannersRequest *request = [self homeRequest];
    request.pinnedBaseUrl = @"https://proxy.example.com/gateway/";

    XCTAssertEqualObjects([request baseUrl], @"");
}

/// Verifies the getInlineBanners call: flat body with the device fields, slots, formats and the native schema version.
- (void)testBodyCarriesSlotsFormatsAndNativeVersion {
    PWGetInlineBannersRequest *request = [self homeRequest];

    NSDictionary *body = [request requestDictionary];

    XCTAssertEqualObjects([request methodName], @"getInlineBanners");
    XCTAssertFalse([request shouldWrapRequest]);
    XCTAssertFalse([request followsServerBaseUrl]);
    XCTAssertEqualObjects(body[@"slots"], (@[@"home_top", @"cart_bottom"]));
    XCTAssertEqualObjects(body[@"formats"], @[@"native"]);
    XCTAssertEqualObjects(body[@"nativeVersion"], @1);
    XCTAssertEqualObjects(body[@"hwid"], [PWPreferences preferences].hwid);
    XCTAssertNotNil(body[@"v"]);
}

/// Verifies that the slots object of the response is kept as is, empty slots included.
- (void)testParsesSlotsObject {
    PWGetInlineBannersRequest *request = [self homeRequest];
    NSDictionary *slots = @{ @"home_top": @{ @"bannerId": @"b1" }, @"cart_bottom": [NSNull null] };

    [request parseResponse:@{ @"slots": slots }];

    XCTAssertEqualObjects(request.slotsResponse, slots);
}

/// Verifies that a response without a slots object leaves no slots response.
- (void)testResponseWithoutSlotsObjectLeavesNoSlots {
    PWGetInlineBannersRequest *request = [self homeRequest];

    [request parseResponse:@{ @"slots": @[] }];

    XCTAssertNil(request.slotsResponse);
}

@end
