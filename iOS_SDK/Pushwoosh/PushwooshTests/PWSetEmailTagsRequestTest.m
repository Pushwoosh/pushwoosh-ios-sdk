//
//  PWSetEmailTagsRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrest/OCHamcrest.h>

#import "PWSetEmailTagsRequest.h"

@interface PWSetEmailTagsRequest (TEST)

@property (nonatomic) NSDictionary *tags;
@property (nonatomic) NSString *email;

@end

@interface PWSetEmailTagsRequestTest : XCTestCase

@property (nonatomic) PWSetEmailTagsRequest *request;

@end

@implementation PWSetEmailTagsRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.request = [[PWSetEmailTagsRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testRequestDictionaryHasParameters {
    [self.request setTags:@{@"test": @"test"}];
    [self.request setEmail:@"test@pushwoosh.com"];
    
    NSDictionary *parameters = [self.request requestDictionary];
    
    assertThat(parameters, hasKey(@"tags"));
    assertThat(parameters, hasKey(@"email"));
    XCTAssertNil(parameters[@"hwid"]);
    XCTAssertNil(parameters[@"content-type"]);
}

- (void)testMethodNameIsCorrect {
    NSString *methodName = [self.request methodName];
    
    XCTAssertEqualObjects(methodName, @"setEmailTags");
}

@end
