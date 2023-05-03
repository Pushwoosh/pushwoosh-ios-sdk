//
//  PWSetTagsTest.m
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 06/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PushNotificationManager.h"
#import "PWSetTagsRequest.h"
#import "PWCombinedSetTagsRequest.h"
#import "PWRequestManager.h"
#import "PWNetworkModule.h"
#import "PWTestUtils.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"

#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

#import <XCTest/XCTest.h>

#include <time.h>
#include <stdlib.h>


@interface SetTagsTest_PWRequestManagerMock : PWRequestManager

- (void)sendRequestInternal:(PWRequest *)request completion:(void (^)(NSError *error))completion;

@property (atomic, assign) void (^onSendRequest)(PWRequest*);

@end

@implementation SetTagsTest_PWRequestManagerMock

- (void)sendRequestInternal:(PWRequest *)request completion:(void (^)(NSError *error))completion {
	if (completion) {
		completion(nil);
	}
	
	if (self.onSendRequest) {
		self.onSendRequest(request);
	}
}

@end


@interface SetTagsTest : XCTestCase

@property (nonatomic, strong) PWRequestManager *originalRequestManager;

@property (nonatomic, strong) SetTagsTest_PWRequestManagerMock *mockRequestManager;

@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;

@end


@implementation SetTagsTest

- (void)setUp {
	[super setUp];
	
	[PWTestUtils setUp];
	
	self.originalRequestManager = [PWNetworkModule module].requestManager;
	self.mockRequestManager = [SetTagsTest_PWRequestManagerMock new];
	[PWNetworkModule module].requestManager = self.mockRequestManager;
	
	self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
	[PWPlatformModule module].notificationManagerCompat = mock([PWNotificationManagerCompat class]);
}

- (void)tearDown {
	[PWNetworkModule module].requestManager = self.originalRequestManager;
	[PWPlatformModule module].notificationManagerCompat = self.originalNotificationManager;
	
	[PWTestUtils tearDown];
	
	[super tearDown];
}

@end
