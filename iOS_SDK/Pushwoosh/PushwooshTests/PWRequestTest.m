//
//  PWRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrest/OCHamcrest.h>

#import "PWRequest.h"
#import "PWUtils.h"
#import "PWPreferences.h"

@interface PWRequest (TEST)

@property (nonatomic) BOOL usePreviousHWID;

- (NSMutableDictionary *)baseDictionary;

@end

@interface PWRequestTest : XCTestCase

@property (nonatomic) PWRequest *request;

@end

@implementation PWRequestTest

- (void)setUp {
    _request = [[PWRequest alloc] init];
}

- (void)tearDown {
    _request = nil;
}

- (void)testBaseDictionaryHasCorrectParameters {
    id mockPWSettings = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWSettings appCode]).andReturn(@"appCode");
    
    NSDictionary *parameters = [self.request baseDictionary];
    
    assertThat(parameters, hasKey(@"userId"));
    assertThat(parameters, hasKey(@"application"));
    assertThat(parameters, hasKey(@"hwid"));
    assertThat(parameters, hasKey(@"v"));
    assertThat(parameters, hasKey(@"device_type"));
    [mockPWSettings stopMocking];
}

- (void)testUsePreviousHwid {
    [self.request setUsePreviousHWID:YES];
    id mockPWUtils = OCMClassMock([PWUtils class]);
    OCMStub([mockPWUtils isValidHwid:OCMOCK_ANY]).andReturn(YES);
    id mockPWSettings = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWSettings previosHWID]).andReturn(@"previous");

    NSDictionary *parameters = [self.request baseDictionary];

    XCTAssertNotNil(parameters);
    OCMVerify([mockPWSettings previosHWID]);
    XCTAssertEqual(parameters[@"hwid"], @"previous");
    [mockPWUtils stopMocking];
    [mockPWSettings stopMocking];
}

- (void)testUsePreviousHwidWithInvalidHwid {
    [self.request setUsePreviousHWID:YES];
    id mockPWUtils = OCMClassMock([PWUtils class]);
    OCMStub([mockPWUtils isValidHwid:OCMOCK_ANY]).andReturn(NO);
    id mockPWSettings = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWSettings previosHWID]).andReturn(@"invalid");
    OCMStub([mockPWSettings hwid]).andReturn(@"current");

    NSDictionary *parameters = [self.request baseDictionary];

    XCTAssertNotNil(parameters);
    XCTAssertEqual(parameters[@"hwid"], @"current");
    [mockPWUtils stopMocking];
    [mockPWSettings stopMocking];
}

- (void)testUidReturnsMethodName {
    NSString *uid = [self.request uid];
    NSString *methodName = [self.request methodName];

    XCTAssertEqualObjects(uid, methodName);
}

- (void)testMethodNameReturnsEmptyString {
    NSString *methodName = [self.request methodName];

    XCTAssertNotNil(methodName);
    XCTAssertEqualObjects(methodName, @"");
}

- (void)testRequestIdentifierReturnsHashString {
    NSString *identifier = [self.request requestIdentifier];

    XCTAssertNotNil(identifier);
    XCTAssertTrue(identifier.length > 0);

    NSString *expectedIdentifier = [NSString stringWithFormat:@"%ld", self.request.hash];
    XCTAssertEqualObjects(identifier, expectedIdentifier);
}

- (void)testRequestIdentifierIsUnique {
    PWRequest *request1 = [[PWRequest alloc] init];
    PWRequest *request2 = [[PWRequest alloc] init];

    NSString *identifier1 = [request1 requestIdentifier];
    NSString *identifier2 = [request2 requestIdentifier];

    XCTAssertNotEqualObjects(identifier1, identifier2);
}

- (void)testRequestDictionaryReturnsNil {
    NSDictionary *dict = [self.request requestDictionary];

    XCTAssertNil(dict);
}

- (void)testParseResponseDoesNotThrow {
    NSDictionary *response = @{@"status": @"OK"};

    XCTAssertNoThrow([self.request parseResponse:response]);
}

- (void)testParseResponseWithNil {
    XCTAssertNoThrow([self.request parseResponse:nil]);
}

- (void)testCacheableProperty {
    self.request.cacheable = YES;
    XCTAssertTrue(self.request.cacheable);

    self.request.cacheable = NO;
    XCTAssertFalse(self.request.cacheable);
}

- (void)testHttpCodeProperty {
    self.request.httpCode = 200;
    XCTAssertEqual(self.request.httpCode, 200);

    self.request.httpCode = 404;
    XCTAssertEqual(self.request.httpCode, 404);
}

- (void)testStartTimeProperty {
    self.request.startTime = 12345;
    XCTAssertEqual(self.request.startTime, 12345);

    self.request.startTime = 67890;
    XCTAssertEqual(self.request.startTime, 67890);
}

- (void)testUsePreviousHWIDProperty {
    self.request.usePreviousHWID = YES;
    XCTAssertTrue(self.request.usePreviousHWID);

    self.request.usePreviousHWID = NO;
    XCTAssertFalse(self.request.usePreviousHWID);
}

- (void)testBaseDictionaryContainsVersion {
    id mockPWSettings = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWSettings appCode]).andReturn(@"appCode");

    NSDictionary *parameters = [self.request baseDictionary];

    XCTAssertNotNil(parameters[@"v"]);
    [mockPWSettings stopMocking];
}

- (void)testBaseDictionaryContainsDeviceType {
    id mockPWSettings = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWSettings appCode]).andReturn(@"appCode");

    NSDictionary *parameters = [self.request baseDictionary];

    XCTAssertNotNil(parameters[@"device_type"]);
    [mockPWSettings stopMocking];
}

- (void)testBaseDictionaryWithNilUserId {
    id mockPWSettings = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWSettings appCode]).andReturn(@"appCode");
    OCMStub([mockPWSettings userId]).andReturn(nil);

    NSDictionary *parameters = [self.request baseDictionary];

    XCTAssertNotNil(parameters);
    [mockPWSettings stopMocking];
}

- (void)testBaseDictionaryReturnsMutableDictionary {
    id mockPWSettings = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWSettings appCode]).andReturn(@"appCode");

    NSMutableDictionary *parameters = [self.request baseDictionary];

    XCTAssertTrue([parameters isKindOfClass:[NSMutableDictionary class]]);

    XCTAssertNoThrow(parameters[@"test"] = @"value");
    [mockPWSettings stopMocking];
}

@end
