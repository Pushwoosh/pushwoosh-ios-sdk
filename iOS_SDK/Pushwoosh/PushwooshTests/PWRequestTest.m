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
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _request = [[PWRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testBaseDictionaryHasCorrectParameters {
    id mockPWPreferences = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWPreferences appCode]).andReturn(@"appCode");
    
    NSDictionary *parameters = [self.request baseDictionary];
    
    assertThat(parameters, hasKey(@"userId"));
    assertThat(parameters, hasKey(@"application"));
    assertThat(parameters, hasKey(@"hwid"));
    assertThat(parameters, hasKey(@"v"));
    assertThat(parameters, hasKey(@"device_type"));
    [mockPWPreferences stopMocking];
}

- (void)testUsePreviousHwid {
    [self.request setUsePreviousHWID:YES];
    id mockPWUtils = OCMClassMock([PWUtils class]);
    OCMStub([mockPWUtils isValidHwid:OCMOCK_ANY]).andReturn(YES);
    id mockPWPreferences = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWPreferences previosHWID]).andReturn(@"previous");
    
    NSDictionary *parameters = [self.request baseDictionary];
    
    XCTAssertNotNil(parameters);
    OCMVerify([mockPWPreferences previosHWID]);
    XCTAssertEqual(parameters[@"hwid"], @"previous");
    [mockPWUtils stopMocking];
    [mockPWPreferences stopMocking];
}

@end
