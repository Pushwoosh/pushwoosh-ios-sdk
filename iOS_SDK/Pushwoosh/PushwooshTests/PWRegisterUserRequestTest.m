//
//  PWRegisterUserRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrest/OCHamcrest.h>

#import "PWRegisterUserRequest.h"

@interface PWRegisterUserRequest (TEST)

@end

@interface PWRegisterUserRequestTest : XCTestCase

@property (nonatomic) PWRegisterUserRequest *request;

@end

@implementation PWRegisterUserRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.request = [[PWRegisterUserRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testMethodNameIsCorrect {
    NSString *methodName = [self.request methodName];
    
    XCTAssertEqualObjects(methodName, @"registerUser");
}

@end
