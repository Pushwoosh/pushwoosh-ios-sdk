//
//  PWTrackInlineEventRequestTest.m
//  PushwooshTests
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWTrackInlineEventRequest.h"
#import "PWGetInlineBannersRequest.h"
#import "PWRequest+Internal.h"
#import "PWConfig.h"
#import "PWNetworkModule.h"
#import "PWRequestManager.h"
#import "PWPreferences.h"

@interface PWTrackInlineEventRequestTest : XCTestCase

@property (nonatomic, strong) id configMock;
@property (nonatomic, strong) id requestManagerMock;

@end

@implementation PWTrackInlineEventRequestTest

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

- (NSDictionary *)showEvent {
    return @{ @"eventId": @"6F9619FF-8B86-D011-B42D-00C04FC964FF", @"type": @"show", @"slotId": @"home_top",
              @"bannerId": @"b1", @"version": @2, @"timestamp": @1800000000, @"test": @NO };
}

/// Verifies the trackInlineEvent call: flat body with the device fields and every field of the event.
- (void)testBodyCarriesDeviceFieldsAndEvent {
    PWTrackInlineEventRequest *request = [[PWTrackInlineEventRequest alloc] initWithEvent:[self showEvent]];

    NSDictionary *body = [request requestDictionary];

    XCTAssertEqualObjects([request methodName], @"trackInlineEvent");
    XCTAssertFalse([request shouldWrapRequest]);
    XCTAssertFalse([request followsServerBaseUrl]);
    XCTAssertEqualObjects(body[@"hwid"], [PWPreferences preferences].hwid);
    XCTAssertNotNil(body[@"v"]);
    [[self showEvent] enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        XCTAssertEqualObjects(body[key], value, @"%@", key);
    }];
}

/// Verifies that an event goes to the same endpoint as the banners it reports on.
- (void)testGoesToTheEndpointOfGetInlineBanners {
    PWTrackInlineEventRequest *event = [[PWTrackInlineEventRequest alloc] initWithEvent:[self showEvent]];
    PWGetInlineBannersRequest *banners = [[PWGetInlineBannersRequest alloc] initWithSlots:@[@"home_top"] formats:@[@"native"]];
    event.pinnedBaseUrl = @"https://ABCDE-12345.api.pushwoosh.com/json/1.3/";
    banners.pinnedBaseUrl = event.pinnedBaseUrl;

    XCTAssertEqualObjects([event baseUrl], @"https://ABCDE-12345.api.pushwoosh.com/api/v2/device-api/");
    XCTAssertEqualObjects([event baseUrl], [banners baseUrl]);
}

@end
