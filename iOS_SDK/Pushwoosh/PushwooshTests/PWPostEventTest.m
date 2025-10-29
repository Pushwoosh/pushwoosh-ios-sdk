//
//  PWPostEventTest.m
//  PushNotificationManager
//
//  Created by etkachenko on 12/23/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PushNotificationManager.h"
#import "PWNetworkModule.h"
#import "PWCache.h"
#import "PWTestUtils.h"
#import "PWRequestManagerMock.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"
#import "PWSendPurchaseRequest.h"
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import "PWRegisterUserRequest.h"
#import "PWPreferences.h"
#import "PWPostEventRequest.h"
#import "PWInAppManager.h"
#import "Pushwoosh+Internal.h"

@interface PWPostEventTest : XCTestCase

@property PushNotificationManager *pushManager;

@property (nonatomic) PWInAppManager *inAppManager;

@property (nonatomic, strong) PWRequestManager *originalRequestManager;

@property (nonatomic, strong) PWRequestManagerMock *mockRequestManager;

@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;

@end

@implementation PWPostEventTest

- (void)setUp {
    [super setUp];
    
    [PWTestUtils setUp];
    
    self.originalRequestManager = [PWNetworkModule module].requestManager;
    self.mockRequestManager = [PWRequestManagerMock new];
    [PWNetworkModule module].requestManager = self.mockRequestManager;
    
    self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
    [PWPlatformModule module].notificationManagerCompat = mock([PWNotificationManagerCompat class]);
    
    self.inAppManager = [PWInAppManager new];
    
    self.pushManager = [PushNotificationManager pushManager];
    [PushNotificationManager initializeWithAppCode:@"4FC89B6D14A655.46488481" appName:@"UnitTest"];
    
}

- (void)tearDown {
    self.pushManager = nil;
    [PWNetworkModule module].requestManager = self.originalRequestManager;
    [PWPlatformModule module].notificationManagerCompat = self.originalNotificationManager;
    
    [PWTestUtils tearDown];
    
    [super tearDown];
}

////- (void)postEvent:withAttributes:completion: part

//tests completion called with error in case request failed
-(void)testPostEventError {
    //Preconditions:
    XCTestExpectation *postEventExpextation = [self expectationWithDescription:@"postEventExpextation"];
    self.mockRequestManager.failed = YES;
    //Steps:
    
    [_inAppManager postEvent:@"testEvent" withAttributes:@{} completion:^(NSError *error) {
        XCTAssertNotNil(error);
        [postEventExpextation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

//tests completion called with error in case empty event string
-(void)testPostEmptyEvent {
    //Preconditions:
    XCTestExpectation *postEventExpextation = [self expectationWithDescription:@"postEventExpextation"];
    self.mockRequestManager.failed = NO;
    
    [_inAppManager postEvent:@"" withAttributes:@{} completion:^(NSError *error) {
        XCTAssertNotNil(error);
        [postEventExpextation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

//tests completion called with error in case empty event string
-(void)testPostEventWithEmptyAppCode {
    
    //Preconditions:
    [PushNotificationManager initializeWithAppCode:@"" appName:@"Name"];
    XCTestExpectation *postEventExpextation = [self expectationWithDescription:@"postEventExpextation"];
    self.mockRequestManager.failed = NO;
    
    [_inAppManager postEvent:@"testEvent" withAttributes:@{} completion:^(NSError *error) {
        XCTAssertNotNil(error);
        [postEventExpextation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

//tests method sends correct request
-(void)testPostEventRequest {
    
    //Preconditions:
    XCTestExpectation *postEventExpextation = [self expectationWithDescription:@"postEventExpextation"];
    NSString *event = @"testEvent";
    NSDictionary *attributesDict = @{@"testAttribute" : @"testAttribute"};
    
    __block PWRequest *postEventRequest = nil;
    self.mockRequestManager.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWPostEventRequest class]]) {
            postEventRequest = request;
        }
    };
    
    //Steps:
    [_inAppManager postEvent:event withAttributes:attributesDict completion:^(NSError *error) {
        XCTAssertNil(error);
        [postEventExpextation fulfill];
        
        //Postconditions:
        NSDictionary *requestDictionary = postEventRequest.requestDictionary;
        NSLog(@"%@", requestDictionary);
        XCTAssertEqualObjects(requestDictionary[@"application"], [PWPreferences preferences].appCode);
        XCTAssertEqualObjects(requestDictionary[@"attributes"], attributesDict);
        XCTAssertEqualObjects(requestDictionary[@"device_type"], @(DEVICE_TYPE));
        XCTAssertEqualObjects(requestDictionary[@"event"], event);
        XCTAssertEqualObjects(requestDictionary[@"hwid"], [PWPreferences preferences].hwid);
        XCTAssertEqualObjects(requestDictionary[@"userId"], [PWPreferences preferences].userId);
        XCTAssertEqualObjects(requestDictionary[@"v"], PUSHWOOSH_VERSION);
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

@end
