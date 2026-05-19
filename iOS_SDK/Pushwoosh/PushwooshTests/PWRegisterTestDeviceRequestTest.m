//
//  PWRegisterTestDeviceRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrest/OCHamcrest.h>

#import "PWRegisterTestDeviceRequest.h"

@interface PWRegisterTestDeviceRequestTest : XCTestCase

@property (nonatomic) PWRegisterTestDeviceRequest *request;

@end

@implementation PWRegisterTestDeviceRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.request = [[PWRegisterTestDeviceRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testMethodNameIsCorrect {
    NSString *methodName = [self.request methodName];
    
    XCTAssertEqualObjects(methodName, @"createTestDevice");
}

- (void)testRequestDictionaryHasCorrectParameters {
    [self.request setName:@"name"];
    [self.request setDesc:@"desc"];
    NSDictionary *parameters = [self.request requestDictionary];
    
    assertThat(parameters, hasKey(@"name"));
    assertThat(parameters, hasKey(@"description"));
}

- (void)testParseResponseIsEmpty {
    [self.request parseResponse:@{}];
}

/// Verifies that auto_created is serialised as @NO when the flag is not set.
- (void)testAutoCreatedFlagFalseByDefault {
    NSDictionary *parameters = [self.request requestDictionary];

    XCTAssertEqualObjects(parameters[@"auto_created"], @NO);
}

/// Verifies that auto_created is serialised as @YES when the flag is set.
- (void)testAutoCreatedFlagTrueWhenSet {
    self.request.autoCreated = YES;

    NSDictionary *parameters = [self.request requestDictionary];

    XCTAssertEqualObjects(parameters[@"auto_created"], @YES);
}

@end
