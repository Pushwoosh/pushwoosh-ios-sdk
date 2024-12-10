//
//  PWPushRecievedTest.m
//  PushNotificationManager
//
//  Created by etkachenko on 12/16/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWRequestManagerMock.h"
#import "PWNetworkModule.h"
#import "PWTestUtils.h"
#import "PushNotificationManager.h"
#import "PWPreferences.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"
#import "PWNotificationCategoryBuilder.h"
#import "PWPushNotificationDelegateMock.h"
#import "PWPushNotificationCustomDelegateMock.h"
#import "PWRegisterDeviceRequest.h"
#import "PWUnregisterDeviceRequest.h"
#import "PWUtils.h"
#import "PWPushStatRequest.h"
#import "PushwooshFramework.h"
#import "PWBundleMock.h"
#import "PWConfig.h"
#import <OCMock/OCMock.h>

#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import <XCTest/XCTest.h>

@interface PWPushRecievedTest : XCTestCase

@property PushNotificationManager *pushManager;

@property (nonatomic, strong) PWRequestManager *originalRequestManager;

@property (nonatomic, strong) PWRequestManagerMock *mockRequestManager;

@property (nonatomic, strong) PWPushNotificationDelegateMock *mockNotificationDelegate;

@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;

@property (nonatomic, strong) PWNotificationManagerCompat *mockNotificationManager;

@property (nonatomic, strong) Class originalCategoryBuilder;

@end

@implementation PWPushRecievedTest

- (void)setUp {
    [super setUp];
    
    self.originalRequestManager = [PWNetworkModule module].requestManager;
    self.mockRequestManager = [PWRequestManagerMock new];
    [PWNetworkModule module].requestManager = self.mockRequestManager;
    
    self.mockNotificationManager = mock([PWNotificationManagerCompat class]);
    self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
    [PWPlatformModule module].notificationManagerCompat = self.mockNotificationManager;
    
    [givenVoid([self.mockNotificationManager getRemoteNotificationStatusWithCompletion:anything()]) willDo:^id (NSInvocation *invocation) {
        NSArray *args = [invocation mkt_arguments];
        void (^completion)(NSDictionary*) = args[0];
        completion(nil);
        return nil;
    }];
    
    self.originalCategoryBuilder = [PWPlatformModule module].NotificationCategoryBuilder;
    [PWPlatformModule module].NotificationCategoryBuilder = [PWNotificationCategoryBuilder class];
    
    self.mockNotificationDelegate = [PWPushNotificationDelegateMock new];
    
    [PushNotificationManager initializeWithAppCode:@"4FC89B6D14A655.46488481" appName:@"UnitTest"];
    self.pushManager = [PushNotificationManager pushManager];
    [PushNotificationManager pushManager].delegate = self.mockNotificationDelegate;
}

- (void)tearDown {
    
    [PWNetworkModule module].requestManager = self.originalRequestManager;
    self.pushManager = nil;
    self.mockNotificationDelegate = nil;
    [PWPlatformModule module].notificationManagerCompat = self.originalNotificationManager;
    [PWPlatformModule module].NotificationCategoryBuilder = self.originalCategoryBuilder;
    [PWTestUtils tearDown];
    
    [super tearDown];
}

////- (BOOL)handlePushReceived:(NSDictionary *)userInfo part

//tests method returns NO if userInfo is not NSDictionary

- (void)testHandlePushReceivedNotNSDictinary {

    //Precondition:
    NSArray *userInfo = [NSArray arrayWithObjects:@"1", @"2", @"3", nil];
 //   NSDictionary *userInfo = @{ @"!aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3" }, @"p" : @"42"};

    //Steps:
    BOOL methodResult = [self.pushManager handlePushReceived:userInfo];
    
    //Postcondition:
    XCTAssertFalse(methodResult);
}

//tests method returns NO if userInfo has no @"aps" dictionary enclosed
- (void)testHandlePushReceivedApsDictionary {
    
    //Precondition:
    NSDictionary *userInfo = @{ @"!aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3" }, @"p" : @"42"};

    //Steps:
    BOOL methodResult = [self.pushManager handlePushReceived:userInfo];
    
    //Postcondition:
    XCTAssertFalse(methodResult);
}

//tests method sends correct request if userInfo has hash enclosed
- (void)testHandlePushReceivedHash {
    [PushNotificationManager pushManager].showPushnotificationAlert = NO;
    
    //Precondition:
    id mockPWConfigPartial = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfigPartial sendPushStatIfAlertsDisabled]).andReturn(YES);
    XCTestExpectation *requestExpectation = [self expectationWithDescription:@"mainQueueExpectation"];
    NSDictionary *userInfo = @{ @"aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3" }, @"p" : @"42", @"pw_msg" : @"1"};
    __block PWRequest *pushStatRequest = nil;
    
    self.mockRequestManager.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWPushStatRequest class]]) {
            pushStatRequest = request;
            [requestExpectation fulfill];
        }
    };
    
    //Steps:
    [self.pushManager handlePushReceived:userInfo];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    //Postcondition:
    XCTAssertEqual(pushStatRequest.requestDictionary[@"hash"], userInfo[@"p"]);
}
//tests method sends correct request if userInfo has nil hash
- (void)testHandlePushReceivedNilHash {
    [PushNotificationManager pushManager].showPushnotificationAlert = NO;
    
    //Precondition:
    id mockPWConfigPartial = OCMPartialMock([PWConfig config]);
    OCMStub([mockPWConfigPartial sendPushStatIfAlertsDisabled]).andReturn(YES);
    XCTestExpectation *requestExpectation = [self expectationWithDescription:@"mainQueueExpectation"];
    NSDictionary *userInfo = @{ @"aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3"}, @"pw_msg" : @"1"};
    __block PWRequest *pushStatRequest = nil;
    __block BOOL requestSent;
    
    self.mockRequestManager.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWPushStatRequest class]]) {
            pushStatRequest = request;
            requestSent = YES;
            [requestExpectation fulfill];
        }
    };
    
    //Steps:
    [self.pushManager handlePushReceived:userInfo];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    //Postcondition:
    XCTAssertEqual(pushStatRequest.requestDictionary[@"hash"], nil);
    XCTAssertTrue(requestSent);
}

//tests method calls delegate for onPushReceived:withNotification:onStart: method
- (void)testHandlePushReceivedOnPushReceivedCalled {
    
    //Precondition:
    NSDictionary *userInfo = @{ @"aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3"}, @"pw_msg" : @"1"};
    
    //Steps:
    BOOL methodResults = [self.pushManager handlePushReceived:userInfo];
    
    //Postcondition:
    [verify(self.mockNotificationDelegate.mock) onPushReceived:self.pushManager withNotification:userInfo onStart:NO];
    XCTAssertTrue(methodResults);
}

////- (NSDictionary *)getApnPayload:(NSDictionary *)pushNotification part

//tests method returns NSDictionary with object for key @"aps"
- (void)testGetApnPayload {
    
    //Precondition:
    NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"pw_msg" : @"1"};

    //Steps:
    id methodResult = [self.pushManager getApnPayload:pushNotification];
    
    //Postcondition:
    XCTAssertTrue([methodResult isKindOfClass:[NSDictionary class]]);
    XCTAssertEqualObjects(methodResult, pushNotification[@"aps"]);
}

////- (NSString *)getCustomPushData:(NSDictionary *)pushNotification part

//tests method returns NSString with object for key @"u"
- (void)testGetApnPayloadGetCustomPushData {
    
    //Precondition:
    NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"u" : @"custom data", @"pw_msg" : @"1"};

    //Steps:
    id methodResult = [self.pushManager getCustomPushData:pushNotification];
    
    //Postcondition:
    XCTAssertTrue([methodResult isKindOfClass:[NSString class]]);
    XCTAssertEqualObjects(methodResult, pushNotification[@"u"]);
}

//tests method returns nil if custom data string is null
- (void)testGetApnPayloadGetCustomPushDataNull {
	
	//Precondition:
	NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"u" : [NSNull null], @"pw_msg" : @"1"};
	
	//Steps:
	id methodResult = [self.pushManager getCustomPushData:pushNotification];
	
	//Postcondition:
	XCTAssertNil(methodResult);
}


////- (NSDictionary *)getCustomPushDataAsNSDict:(NSDictionary *)pushNotification part

//tests method returns nil if custom data string is nil
- (void)testGetApnPayloadNilCustomPushDataAsNSDict {
    
    //Precondition:
    NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"pw_msg" : @"1"};
    
    //Steps:
    id methodResult = [self.pushManager getCustomPushDataAsNSDict:pushNotification];
    
    //Postcondition:
    XCTAssertNil(methodResult);
}

//tests method returns nil if custom data string is null
- (void)testGetApnPayloadNullCustomPushDataAsNSDict {
	
	//Precondition:
	NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"u" : [NSNull null], @"pw_msg" : @"1"};
	
	//Steps:
	id methodResult = [self.pushManager getCustomPushDataAsNSDict:pushNotification];
	
	//Postcondition:
	XCTAssertNil(methodResult);
}

//tests method returns nil if custom data string is nil
- (void)testGetApnPayloadArrayCustomPushDataAsNSDict {
	
	//Precondition:
	NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"u" : @"[1, \"b\"]", @"pw_msg" : @"1"};
	
	//Steps:
	id methodResult = [self.pushManager getCustomPushDataAsNSDict:pushNotification];
	
	//Postcondition:
	XCTAssertNil(methodResult);
}


//tests method returns NSDictionary with customData dictionary
- (void)testGetApnPayloadGetCustomPushDataAsNSDict {
    
    //Precondition:
    NSDictionary *pushNotification = @{ @"aps" : @{ @"alert" : @{ @"body" : @"push message"}}, @"u" : @"{\"r\":30, \"g\":144, \"b\":255}"};

    //Steps:
    id methodResult = [self.pushManager getCustomPushDataAsNSDict:pushNotification];
    
    //Postcondition:

    XCTAssertTrue([methodResult isKindOfClass:[NSDictionary class]]);

    XCTAssertEqualObjects(methodResult[@"r"], @30);
    XCTAssertEqualObjects(methodResult[@"g"], @144);
    XCTAssertEqualObjects(methodResult[@"b"], @255);
}

@end
