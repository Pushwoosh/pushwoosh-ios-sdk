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

@property (nonatomic) PWPreferences *settings;
@property (nonatomic) PWConfig *config;


@end

@implementation PWPreferencesTest

- (void)setUp {
    _settings = [PWPreferences preferences];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testAppGroupsNameIsEmpty {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(nil);
    id mockNSUserDefaults = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    OCMExpect([mockNSUserDefaults objectForKey:@"PWInAppUserId"]).andReturn(@"someUserID");

    _settings = [[PWPreferences alloc] init];

    OCMVerifyAll(mockNSUserDefaults);
    XCTAssertEqual([_settings userId], @"someUserID");
    [mockNSUserDefaults stopMocking];
}

- (void)testUserUpdatedSDKAndChangeUserDefaultsToAppGroups {
    NSString *appGroupName = @"someAppGroup";
    NSString *prevSavedUserId = @"prevSavedUserId";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(appGroupName);
    id mockNSUserDefaults = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    OCMStub([mockNSUserDefaults objectForKey:@"PWInAppUserId"]).andReturn(prevSavedUserId);

    _settings = [[PWPreferences alloc] init];

    XCTAssertEqual([_settings userId], prevSavedUserId);
    [mockNSUserDefaults stopMocking];
}

- (void)testUserIdFromSuiteName {
    NSString *appGroupName = @"someAppGroup";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(appGroupName);
    id mockNSUSerDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockNSUSerDefaults alloc]).andReturn(mockNSUSerDefaults);
    OCMStub([mockNSUSerDefaults initWithSuiteName:OCMOCK_ANY]).andReturn(mockNSUSerDefaults);

    _settings = [[PWPreferences alloc] init];

    OCMVerifyAll(mockNSUSerDefaults);
}

- (void)testSetUserIdAppGroupNameNil {
    NSString *kUserId = @"PWInAppUserId";
    NSString *mockUserId = @"mockUserId";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(nil);
    id mockNSUserDefaults = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    OCMExpect([mockNSUserDefaults setObject:mockUserId forKey:kUserId]);
    
    [_settings setUserId:mockUserId];
    
    OCMVerifyAll(mockNSUserDefaults);
}

@end
