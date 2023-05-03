//
//  PWPreferencesTest.m
//  PushwooshTests
//
//  Created by Andrei Kiselev on 25.4.23..
//  Copyright © 2023 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWPreferences.h"
#import "PWConfig.h"

@interface PWPreferences (Test)

@property (nonatomic) NSUserDefaults *defaults;
@property (copy) NSString *userId;

@end

@interface PWPreferencesTest : XCTestCase

@property (nonatomic) PWPreferences *preference;
@property (nonatomic) PWConfig *config;


@end

@implementation PWPreferencesTest

- (void)setUp {
    _preference = [PWPreferences preferences];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testAppGroupsNameIsEmpty {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(nil);
    id mockNSUserDefaults = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    OCMExpect([mockNSUserDefaults objectForKey:@"PWInAppUserId"]).andReturn(@"someUserID");
    
    _preference = [[PWPreferences alloc] init];
    
    OCMVerifyAll(mockNSUserDefaults);
    XCTAssertEqual([_preference userId], @"someUserID");
    [mockNSUserDefaults stopMocking];
}

- (void)testUserUpdatedSDKAndChangeUserDefaultsToAppGroups {
    NSString *appGroupName = @"someAppGroup";
    NSString *prevSavedUserId = @"prevSavedUserId";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(appGroupName);
    id mockNSUserDefaults = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    OCMStub([mockNSUserDefaults objectForKey:@"PWInAppUserId"]).andReturn(prevSavedUserId);
    
    _preference = [[PWPreferences alloc] init];
    
    XCTAssertEqual([_preference userId], prevSavedUserId);
    [mockNSUserDefaults stopMocking];
}

- (void)testUserIdFromSuiteName {
    NSString *appGroupName = @"someAppGroup";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(appGroupName);
    id mockNSUSerDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockNSUSerDefaults alloc]).andReturn(mockNSUSerDefaults);
    OCMStub([mockNSUSerDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUSerDefaults);
    
    _preference = [[PWPreferences alloc] init];
    
    OCMVerifyAll(mockNSUSerDefaults);
}

- (void)testSetUserIdWithAppGroupName {
    NSString *mockUserId = @"mockUserId";
    NSString *appGroupName = @"someAppGroup";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(appGroupName);
    id mockNSUSerDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockNSUSerDefaults alloc]).andReturn(mockNSUSerDefaults);
    OCMStub([mockNSUSerDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUSerDefaults);
    OCMExpect([mockNSUSerDefaults setObject:OCMOCK_ANY forKey:OCMOCK_ANY]);
    
    [_preference setUserId:mockUserId];
    
    OCMVerifyAll(mockNSUSerDefaults);
}

- (void)testSetUserIdAppGroupNameNil {
    NSString *kUserId = @"PWInAppUserId";
    NSString *mockUserId = @"mockUserId";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(nil);
    id mockNSUserDefaults = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    OCMExpect([mockNSUserDefaults setObject:mockUserId forKey:kUserId]);
    
    [_preference setUserId:mockUserId];
    
    OCMVerifyAll(mockNSUserDefaults);
}

@end
