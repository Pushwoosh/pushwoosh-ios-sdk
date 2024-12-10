//
//  PushwooshTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PushwooshFramework.h"
#import "PWPreferences.h"
#import "PWRequestsCacheManager.h"
#import "PWInAppManager.h"
#import "PWConfig.h"
#import "PWPushNotificationsManager.h"

@interface Pushwoosh (TEST)

- (instancetype)initWithApplicationCode:(NSString *)appCode;

@end

@interface PushwooshTest : XCTestCase

@property (nonatomic) Pushwoosh *pushwoosh;

@end

@implementation PushwooshTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.pushwoosh = [[Pushwoosh alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testInitWithApplicationCode {
    id mockPWRequestsCacheManager = OCMClassMock([PWRequestsCacheManager class]);
    OCMStub([mockPWRequestsCacheManager sharedInstance]);
    id mockPWInAppManager = OCMClassMock([PWInAppManager class]);
    OCMStub([mockPWInAppManager sharedManager]);
    id mockPWConfig = OCMClassMock([PWConfig class]);
    OCMStub([mockPWConfig config]);
    
    id result = [self.pushwoosh initWithApplicationCode:@"DC533-F5DA4"];
    
    XCTAssert(result);
    XCTAssertEqual([PWPreferences preferences].appCode, @"DC533-F5DA4");
    OCMVerify([mockPWRequestsCacheManager sharedInstance]);
    OCMVerify([mockPWInAppManager sharedManager]);
    OCMVerify([mockPWConfig config]);
    [mockPWRequestsCacheManager stopMocking];
    [mockPWInAppManager stopMocking];
    [mockPWConfig stopMocking];
}

- (void)testCheckTagsAreExistWhenRegisterForNotifyCalled {
    NSDictionary *customTags = @{@"k1":@"v1", @"k2": @"v2"};
    
    [[Pushwoosh sharedInstance] registerForPushNotificationsWith:customTags
                                                      completion:^(NSString * _Nullable token, NSError * _Nullable error) {}];
    
    XCTAssertEqual(customTags, [[PWPreferences preferences] customTags]);
}

- (void)testCheckCustomTagsNullIfPassedNull {
    [[Pushwoosh sharedInstance] registerForPushNotificationsWith:nil];
    
    XCTAssertNil([[PWPreferences preferences] customTags]);
}

@end
