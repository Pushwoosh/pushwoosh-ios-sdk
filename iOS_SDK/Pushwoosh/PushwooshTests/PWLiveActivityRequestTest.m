//
//  PWLiveActivityRequestTest.m
//  PushwooshTests
//
//  Created by Andrew Kis on 4.7.24..
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWLiveActivityRequest.h"

@interface PWLiveActivityRequestTest : XCTestCase

@property (nonatomic) PWLiveActivityRequest *request;

@end

@interface PWLiveActivityRequest (TEST)

- (NSString *)methodName;
- (NSDictionary *)requestDictionary;

@end

@implementation PWLiveActivityRequestTest

- (void)setUp {
    _request = [[PWLiveActivityRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testMethodName {
    NSString *methodName = @"setActivityToken";
    
    XCTAssertEqualObjects([_request methodName], methodName);
}

- (void)testRequestDictionaryWithActivityId {
    self.request.token = @"testToken";
    self.request.activityId = @"testActivityId";
    
    XCTAssertEqual([[_request requestDictionary] objectForKey:@"activity_token"], self.request.token);
    XCTAssertEqual([[_request requestDictionary] objectForKey:@"activity_id"], self.request.activityId);
}

- (void)testRequestDictionaryWithoutActivityId {
    self.request.token = @"testToken";
    self.request.activityId = @"";

    
    XCTAssertEqual([[_request requestDictionary] objectForKey:@"activity_id"], self.request.activityId);
    XCTAssertEqual([[_request requestDictionary] objectForKey:@"activity_token"], self.request.token);
}

@end
