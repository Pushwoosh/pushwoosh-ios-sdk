//
//  PWMergeUserRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrest/OCHamcrest.h>

#import "PWMergeUserRequest.h"

@interface PWMergeUserRequest (TEST)

@property (nonatomic, copy) NSString *srcUserId;
@property (nonatomic, copy) NSString *dstUserId;
@property (nonatomic, assign) BOOL doMerge;

@end

@interface PWMergeUserRequestTest : XCTestCase

@property (nonatomic) PWMergeUserRequest *request;

@end

@implementation PWMergeUserRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.request = [[PWMergeUserRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testMethodNameIsCorrect {
    NSString *methodName = [self.request methodName];
    
    XCTAssertEqualObjects(methodName, @"mergeUser");
}

- (void)testRequestDictionaryHasParameters {
    [self.request setSrcUserId:@"user"];
    [self.request setDstUserId:@"user_dst"];
    [self.request setDoMerge:YES];
    
    NSDictionary *parameters = [self.request requestDictionary];
    
    assertThat(parameters, hasKey(@"oldUserId"));
    assertThat(parameters, hasKey(@"newUserId"));
    assertThat(parameters, hasKey(@"merge"));
    assertThat(parameters, hasKey(@"ts"));
}

@end
