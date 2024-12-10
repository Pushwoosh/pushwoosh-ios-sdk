//
//  PWRegisterEmailTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrest/OCHamcrest.h>

#import "PWRegisterEmail.h"


@interface PWRegisterEmail (TEST)

@property (nonatomic) NSString *email;

@end

@interface PWRegisterEmailTest : XCTestCase

@property (nonatomic) PWRegisterEmail *request;

@end

@implementation PWRegisterEmailTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.request = [[PWRegisterEmail alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testRequestDictionaryHasParameters {
    [self.request setEmail:@"test@pushwoosh.com"];
    
    NSDictionary *parameters = [self.request requestDictionary];
    
    assertThat(parameters, hasKey(@"email"));
    assertThat(parameters, hasKey(@"language"));
    assertThat(parameters, hasKey(@"tz_offset"));
    XCTAssertNil(parameters[@"hwid"]);
    XCTAssertNil(parameters[@"device_type"]);
}

- (void)testMethodNameIsCorrect {
    NSString *methodName = [self.request methodName];
    
    XCTAssertEqualObjects(methodName, @"registerEmail");
}

@end
