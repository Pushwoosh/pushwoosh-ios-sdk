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

@interface PWSetTagsRequest (TEST)
@property (nonatomic) NSDictionary *tags;
@end


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

/// Valid tag value types (string, number, array) are preserved in the serialized dictionary.
- (void)testRequestDictionaryKeepsValidTagTypes {
	PWSetTagsRequest *request = [PWSetTagsRequest new];
	request.tags = @{@"str": @"hello", @"num": @42, @"arr": @[@"a", @"b"]};

	NSDictionary *tags = [request requestDictionary][@"tags"];

	XCTAssertEqualObjects(tags[@"str"], @"hello");
	XCTAssertEqualObjects(tags[@"num"], @42);
	XCTAssertEqualObjects(tags[@"arr"], (@[@"a", @"b"]));
}

/// A "#pwinc#" prefixed string is converted into an increment-operation dictionary.
- (void)testRequestDictionaryConvertsIncrementPrefix {
	PWSetTagsRequest *request = [PWSetTagsRequest new];
	request.tags = @{@"counter": @"#pwinc#5"};

	NSDictionary *tags = [request requestDictionary][@"tags"];

	XCTAssertEqualObjects(tags[@"counter"][@"operation"], @"increment");
	XCTAssertEqualObjects(tags[@"counter"][@"value"], @5);
}

/// NaN and infinity number values are excluded so JSON serialization cannot throw.
- (void)testRequestDictionaryExcludesNaNAndInfinity {
	PWSetTagsRequest *request = [PWSetTagsRequest new];
	request.tags = @{@"good": @"ok", @"nan": @(NAN), @"inf": @(INFINITY)};

	NSDictionary *dictionary = [request requestDictionary];
	NSDictionary *tags = dictionary[@"tags"];

	XCTAssertEqualObjects(tags[@"good"], @"ok");
	XCTAssertNil(tags[@"nan"]);
	XCTAssertNil(tags[@"inf"]);
	XCTAssertTrue([NSJSONSerialization isValidJSONObject:dictionary]);
}

/// Non-serializable value types (e.g. NSURL) are dropped instead of crashing serialization.
- (void)testRequestDictionaryExcludesNonSerializableValues {
	PWSetTagsRequest *request = [PWSetTagsRequest new];
	request.tags = @{@"good": @"ok", @"url": [NSURL URLWithString:@"http://example.test"]};

	NSDictionary *tags = [request requestDictionary][@"tags"];

	XCTAssertEqualObjects(tags[@"good"], @"ok");
	XCTAssertNil(tags[@"url"]);
}

@end
