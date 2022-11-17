//
//  PWGetConfigRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 14.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWGetConfigRequest.h"

@interface PWGetConfigRequest (TEST)

- (void)parseResponse:(NSDictionary *)response;

@end

@interface PWGetConfigRequestTest : XCTestCase

@property (nonatomic) PWGetConfigRequest *request;

@end

@implementation PWGetConfigRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.request = [[PWGetConfigRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testIsLoggerActiveFalseWhenResponseIsFalse {
    NSDictionary *response = nil;
    
    [self.request parseResponse:response];
    
    XCTAssertFalse(self.request.isLoggerActive);
}

- (void)testIsLoggerActiveTrueIfResponseIsValidAndHaveLoggerKey {
    NSDictionary *response = @{@"features": @{@"logger": @1}};
    
    [self.request parseResponse:response];
    
    XCTAssertTrue(self.request.isLoggerActive);
}

- (void)testIsLoggerActiveFalseIfLoggerValueIsZero {
    NSDictionary *response = @{@"features": @{@"logger": @0}};
    
    [self.request parseResponse:response];
    
    XCTAssertFalse(self.request.isLoggerActive);
}

@end
