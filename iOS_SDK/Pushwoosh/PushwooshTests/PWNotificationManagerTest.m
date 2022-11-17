//
//  PWNotificationManagerTest.m
//  PushNotificationManager
//
//  Created by etkachenko on 12/15/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWTestUtils.h"
#import "PushNotificationManager.h"
#import "PWPreferences.h"
#import "PWPlatformModule.h"
#import "PWNotificationCategoryBuilder.h"

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>
#import <XCTest/XCTest.h>

@interface PWNotificationManagerTest : XCTestCase

@property PushNotificationManager *pushManager;

@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;

@end

@implementation PWNotificationManagerTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    id notificationManagerMock = mock([PWNotificationManagerCompat class]);
    self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
    [PWPlatformModule module].notificationManagerCompat = notificationManagerMock;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
    [PWPlatformModule module].notificationManagerCompat = self.originalNotificationManager;
    [PWTestUtils tearDown];
}

////+ (PushNotificationManager *)pushManager part

//tests method creates PushNotificationManager object
- (void)testPushManager { //
    
    //Precondition:
    
    
    //Steps:
    id pushManager = [PushNotificationManager pushManager];
    
    
    //Postcondition:
    
     XCTAssertTrue([pushManager isKindOfClass:[PushNotificationManager class]]);
}

////+ (void)initializeWithAppCode:(NSString *)appCode appName:(NSString *)appName part

//tests method creates object with correct appCode and appName
- (void)testInitializeWithAppCode {
    
    //Precondition:
    PushNotificationManager *pushManager = [PushNotificationManager pushManager];
    
    //Steps:
    [PushNotificationManager initializeWithAppCode:@"testString1" appName:@"testString2"];
    
    
    //Postcondition:
    XCTAssertEqualObjects(pushManager.appCode, @"testString1");
}


@end
