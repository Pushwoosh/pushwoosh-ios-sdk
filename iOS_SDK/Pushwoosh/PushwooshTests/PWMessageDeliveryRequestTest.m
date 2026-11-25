//
//  PWMessageDeliveryRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrest/OCHamcrest.h>

#import "PWMessageDeliveryRequest.h"
#import "PWMessageDeliveryRequest+Internal.h"

@interface PWMessageDeliveryRequestTest : XCTestCase

@property (nonatomic) PWMessageDeliveryRequest *request;

@end

@implementation PWMessageDeliveryRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.request = [[PWMessageDeliveryRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testRequestIsCachableTrue {
    XCTAssertTrue([self.request cacheable]);
}

- (void)testMethodNameIsCorrect {
    NSString *methodName = [self.request methodName];

    XCTAssertEqualObjects(methodName, @"messageDeliveryEvent");
}

- (void)testRequestDictionaryHasParameters {
    [self.request setPushDict:@{@"md": @"md"}];

    NSDictionary *parameters = [self.request requestDictionary];

    assertThat(parameters, hasKey(@"metaData"));
}

/// Verifies the receive date is sent as an RFC 3339 UTC string truncated to whole seconds.
- (void)testReceivedAtIsWholeSecondsUTC {
    self.request.receivedDate = [NSDate dateWithTimeIntervalSince1970:1795000000.9];
    XCTAssertEqualObjects(self.request.requestDictionary[@"receivedAt"], @"2026-11-18T11:06:40Z");
    XCTAssertNil(self.request.requestDictionary[@"timestampUTC"]);
}

/// Verifies zero seconds are still written out.
- (void)testReceivedAtKeepsZeroSeconds {
    self.request.receivedDate = [NSDate dateWithTimeIntervalSince1970:1794999600];
    XCTAssertEqualObjects(self.request.requestDictionary[@"receivedAt"], @"2026-11-18T11:00:00Z");
}

/// Verifies no receive time is sent without a receive date and the rest of the body is unchanged.
- (void)testNoReceivedDateSendsNoReceivedAt {
    self.request.pushDict = @{@"p": @"h", @"md": @"m"};
    XCTAssertNil(self.request.requestDictionary[@"receivedAt"]);
    XCTAssertNil(self.request.requestDictionary[@"timestampUTC"]);
    XCTAssertEqualObjects(self.request.requestDictionary[@"hash"], @"h");
    XCTAssertEqualObjects(self.request.requestDictionary[@"metaData"], @"m");
}

/// Verifies the receive time does not depend on the device time zone.
- (void)testReceivedAtIgnoresDeviceTimeZone {
    NSTimeZone *saved = [NSTimeZone defaultTimeZone];
    [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneWithName:@"Asia/Kolkata"]];
    self.request.receivedDate = [NSDate dateWithTimeIntervalSince1970:1795000000];
    NSString *value = self.request.requestDictionary[@"receivedAt"];
    [NSTimeZone setDefaultTimeZone:saved];
    XCTAssertEqualObjects(value, @"2026-11-18T11:06:40Z");
}

@end
