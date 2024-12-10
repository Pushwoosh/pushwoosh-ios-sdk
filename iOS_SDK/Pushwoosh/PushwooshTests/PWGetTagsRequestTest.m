//
//  PWGetTagsRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrest/OCHamcrest.h>

#import "PWGetTagsRequest.h"

@interface PWGetTagsRequest (TEST)

@property (nonatomic, copy) NSDictionary *tags;

@end

@interface PWGetTagsRequestTest : XCTestCase

@property (nonatomic) PWGetTagsRequest *request;

@end

@implementation PWGetTagsRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.request = [[PWGetTagsRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testMethodNameIsCorrect {
    NSString *methodName = [self.request methodName];
    
    XCTAssertEqualObjects(methodName, @"getTags");
}

- (void)testRequestDictionaryHasParameters {
    PWRequest *request = [[PWRequest alloc] init];
    NSDictionary *dict = [request baseDictionary];
    
    NSDictionary *parameters = [self.request requestDictionary];
    
    XCTAssertEqualObjects(dict, parameters);
}

- (void)testParseResponse {
    NSDictionary *tags = @{@"test": @"test"};
    
    [self.request parseResponse:@{@"result": tags}];
    
    XCTAssertEqualObjects(tags, self.request.tags);
}

@end
