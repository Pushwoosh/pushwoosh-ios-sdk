
#import <XCTest/XCTest.h>

#import "PushNotificationManager.h"
#import "PWNetworkModule.h"
#import "PWRequestManager.h"
#import "PWTestUtils.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"

#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

@interface APNSPayloadTest : XCTestCase

@property (nonatomic, strong) PWRequestManager *requestManager;

@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;

@end

@implementation APNSPayloadTest

- (void)setUp {
    [super setUp];
	
	[PWTestUtils setUp];
	
	self.requestManager = [PWNetworkModule module].requestManager;
	[PWNetworkModule module].requestManager = mock([PWRequestManager class]);
	
	self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
	[PWPlatformModule module].notificationManagerCompat = mock([PWNotificationManagerCompat class]);
}

- (void)tearDown {
	[PWNetworkModule module].requestManager = self.requestManager;
	[PWPlatformModule module].notificationManagerCompat = self.originalNotificationManager;
	
	[PWTestUtils tearDown];
	
    [super tearDown];
}

- (void)testNormalPayload {
	[[PushNotificationManager pushManager] handlePushReceived:@{ @"aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3" }, @"p" : @"42" }];
}

- (void)testComplexAlert {
	[[PushNotificationManager pushManager] handlePushReceived:@{ @"aps" : @{ @"alert" : @{ @"title" : @"sup?", @"body" : @"push message"}, @"badge" : @3, @"sound" : @"sound.mp3" }, @"p" : @"42" }];
}

- (void)testStartPush {
	[[PushNotificationManager pushManager] handlePushReceived:@{ UIApplicationLaunchOptionsLocationKey : @{ @"aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3" }, @"p" : @[] }}];
}

- (void)testEmptyPayload {
	[[PushNotificationManager pushManager] handlePushReceived:@{}];
}

- (void)testArrayPayload {
	[[PushNotificationManager pushManager] handlePushReceived:@[]];
}

- (void)testEmptyAps {
	[[PushNotificationManager pushManager] handlePushReceived:@{ @"aps" : @{}}];
}

- (void)testArrayAps {
	[[PushNotificationManager pushManager] handlePushReceived:@{ @"aps" : @[]}];
}

- (void)testBadHashType {
	[[PushNotificationManager pushManager] handlePushReceived:@{ @"aps" : @{ @"alert" : @"push message", @"badge" : @3, @"sound" : @"sound.mp3" }, @"p" : @[] }];
}

@end
