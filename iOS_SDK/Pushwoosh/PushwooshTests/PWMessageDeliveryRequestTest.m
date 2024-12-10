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

@end
