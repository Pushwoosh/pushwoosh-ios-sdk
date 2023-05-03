//
//  PWBasePushTrackingRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrest/OCHamcrest.h>

#import "PWBasePushTrackingRequest.h"

@interface PWBasePushTrackingRequestTest : XCTestCase

@property (nonatomic) PWBasePushTrackingRequest *request;

@end

@implementation PWBasePushTrackingRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.request = [[PWBasePushTrackingRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testIsCachableTrue {
    XCTAssertTrue([self.request cacheable]);
}

- (void)testRequestDictionaryHasCorrectParameters {
    [self.request setPushDict:@{@"p": @"p"}];
    
    NSDictionary *parameters = [self.request requestDictionary];
    
    assertThat(parameters, hasKey(@"hash"));
}

@end
