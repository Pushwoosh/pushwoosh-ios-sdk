//
//  PWInAppMessagesManagerTest.m
//  PushwooshTests
//
//  Created by Andrei Kiselev on 11.7.22..
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import "PWInAppMessagesManager.h"
#import "PWPreferences.h"
#import "PWTriggerInAppActionRequest.h"

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface PWInAppMessagesManager (TEST)

- (void)setUserId:(NSString *)userId completion:(void(^)(NSError * error))completion;
- (void)registerEmailUser:(NSString *)email userId:(NSString *)userId;

@end

@interface PWInAppMessagesManagerTest : XCTestCase

@end

@implementation PWInAppMessagesManagerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testSetUserId {
    NSString *userId = @"1234567890";
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    
    [manager setUserId:userId completion:^(NSError *error) {}];
    
    XCTAssertEqual(userId, [PWPreferences preferences].userId);
}

- (void)testSetUserIdEqualNil {
    NSString *userId = nil;
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    id mockPWPreference = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWPreference userId]).andReturn(nil);
    
    [manager setUserId:userId completion:^(NSError *error) {}];
    
    XCTAssertNil([PWPreferences preferences].userId);
}

- (void)testRegisterEmailUserWithUserNotNil {
    NSString *userId = @"1234567890";
    NSString *email = @"test@test.com";
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    
    [manager registerEmailUser:email userId:userId];
    
    XCTAssertEqual(userId, [PWPreferences preferences].userId);
}

- (void)testRichMedia {
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    PWTriggerInAppActionRequest *request = [PWTriggerInAppActionRequest new];
    id mockPWTriggerInAppActionRequest = OCMClassMock([PWTriggerInAppActionRequest class]);
    OCMStub([mockPWTriggerInAppActionRequest new]).andReturn(request);
    
    [manager trackInAppWithCode:@"r-XXXXX-XXXX5" action:@"action" messageHash:@"__xczafasdadgsdf"];
    
    XCTAssertEqualObjects(request.inAppCode, @"");
    XCTAssertEqual(request.messageHash, @"__xczafasdadgsdf");
    XCTAssertEqualObjects(request.richMediaCode, @"XXXXX-XXXX5");
    [mockPWTriggerInAppActionRequest stopMocking];
}

- (void)testOpenInApp {
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    PWTriggerInAppActionRequest *request = [PWTriggerInAppActionRequest new];
    id mockPWTriggerInAppActionRequest = OCMClassMock([PWTriggerInAppActionRequest class]);
    OCMStub([mockPWTriggerInAppActionRequest new]).andReturn(request);
    
    [manager trackInAppWithCode:@"12345-67890" action:@"action" messageHash:@""];
    
    XCTAssertEqual(request.inAppCode, @"12345-67890");
    XCTAssertEqual(request.messageHash, @"");
    XCTAssertNil(request.richMediaCode);
    [mockPWTriggerInAppActionRequest stopMocking];
}

@end
