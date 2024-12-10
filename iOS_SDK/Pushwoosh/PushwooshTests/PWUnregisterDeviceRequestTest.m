//
//  PWUnregisterDeviceRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWUnregisterDeviceRequest.h"

@interface PWUnregisterDeviceRequest (TEST)

- (BOOL)isLoggable;
- (NSString *)methodName;

@end

@interface PWUnregisterDeviceRequestTest : XCTestCase

@property (nonatomic) PWUnregisterDeviceRequest *request;

@end

@implementation PWUnregisterDeviceRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _request = [[PWUnregisterDeviceRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testCorrectMethodName {
    NSString *methodName = [self.request methodName];
    
    XCTAssertEqualObjects(methodName, @"unregisterDevice");
}

@end
