//
//  PWGetTagsTest.m
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 06/12/16.
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

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

@interface GetTagsTest : XCTestCase

@property PushNotificationManager *pushManager;

@property (nonatomic, strong) PWRequestManager *originalRequestManager;

@property (nonatomic, strong) PWRequestManagerMock *mockRequestManager;

@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;

@end

@implementation GetTagsTest

- (void)setUp {
	[super setUp];
	
	[PWTestUtils setUp];
	
	self.originalRequestManager = [PWNetworkModule module].requestManager;
	self.mockRequestManager = [PWRequestManagerMock new];
	[PWNetworkModule module].requestManager = self.mockRequestManager;
	
	self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
	[PWPlatformModule module].notificationManagerCompat = mock([PWNotificationManagerCompat class]);
	
	[PushNotificationManager initializeWithAppCode:@"4FC89B6D14A655.46488481" appName:@"UnitTest"];
	self.pushManager = [PushNotificationManager pushManager];
}

- (void)tearDown {
	self.pushManager = nil;
	[PWNetworkModule module].requestManager = self.originalRequestManager;
	[PWPlatformModule module].notificationManagerCompat = self.originalNotificationManager;
	
	[PWTestUtils tearDown];
	
	[super tearDown];
}

/**
 * Test result: OK, response: { "result" : {} }
 */
- (void)testGetEmptyTags {
    
    //Preconditions:
	self.mockRequestManager.failed = NO;
	self.mockRequestManager.response = @{ @"result" : @{} };
	
	XCTestExpectation *tagsExpectation = [self expectationWithDescription:@"tags loaded"];
    
    //Steps:
	[self.pushManager loadTags:^(NSDictionary * tags) {
		XCTAssertNotNil(tags, @"Tags are nil");
		XCTAssertTrue([tags isKindOfClass: [NSDictionary class]], @"Tags are not NSDictionary");
		XCTAssertTrue([tags isEqualToDictionary:[NSDictionary new]], @"Error: expected tags: (%@) returned tags: (%@)", [NSDictionary new], tags);
		
		[tagsExpectation fulfill];
	} error:^(NSError* e){
		XCTFail (@"Failed to load tags: " );
		[tagsExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:5 handler:nil];
    
    //Postconditions:
}

- (NSDictionary *)injectedTags {
    return @{ @"testIntTag" : [PWTags incrementalTagWithInteger:5], @"testStringTag" : @"testString", @"testListTag" : @[ @1, @"coockie", @YES] };
}

/**
 * Test result: OK, response: { "result" : { "result" : { "testIntTag" : 1, "testStringTag" : "testString", "testListTag" : [ 1, "coockie", true] } } }
 */
- (void)testGetTags {
    
    //Preconditions:
    NSDictionary *injectedTags = self.injectedTags;
	self.mockRequestManager.failed = NO;
	self.mockRequestManager.response = @{ @"result" : injectedTags };
	
	XCTestExpectation *tagsExpectation = [self expectationWithDescription:@"tags loaded"];
	
    //Steps:
	[self.pushManager loadTags:^(NSDictionary * tags) {
		XCTAssertNotNil(tags, @"Tags are nil");
		XCTAssertTrue([tags isKindOfClass: [NSDictionary class]], @"Tags are not NSDictionary");
		XCTAssertTrue([tags isEqualToDictionary:injectedTags], @"Error: expected tags: (%@) returned tags: (%@)", [NSDictionary new], tags);
		
		[tagsExpectation fulfill];
	} error:^(NSError* e){
		XCTFail (@"Failed to load tags: " );
		[tagsExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:5 handler:nil];
    
    //Postconditions:
}

/**
 * Test result: FAIL, response: null, cache: { "testIntTag" : 1, "testStringTag" : "testString2", "testListTag" : [ 1, "coockie", true] } }
 */
- (void)testGetTagsFromCache {
    
    //Preconditions:
	self.mockRequestManager.failed = YES;
	self.mockRequestManager.response = nil;
	
	NSDictionary *injectedTags = self.injectedTags;
	[[PWCache cache] setTags:injectedTags];
	
	XCTestExpectation *tagsExpectation = [self expectationWithDescription:@"tags loaded"];
	
    //Steps:
	[self.pushManager loadTags:^(NSDictionary * tags) {
		XCTAssertNotNil(tags, @"Tags are nil");
		XCTAssertTrue([tags isKindOfClass: [NSDictionary class]], @"Tags are not NSDictionary");
		XCTAssertTrue([tags isEqualToDictionary:injectedTags], @"Error: expected tags: (%@) returned tags: (%@)", [NSDictionary new], tags);
		
		[tagsExpectation fulfill];
	} error:^(NSError* e){
		XCTFail (@"Failed to load tags: " );
		[tagsExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:5 handler:nil];
    
    //Postconditions:
}

/**
 * Test result: FAIL, response: null, cache: empty
 */
- (void)testGetTagsFailed {
    
    //Preconditions:
	self.mockRequestManager.failed = YES;
	self.mockRequestManager.response = nil;
	
	XCTestExpectation *tagsExpectation = [self expectationWithDescription:@"tags loaded"];
    
    //Steps:
	[self.pushManager loadTags:^(NSDictionary * tags) {
		XCTFail (@"Excepted fail");
		
		[tagsExpectation fulfill];
	} error:^(NSError* e){
		[tagsExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:5 handler:nil];
}

/**
 * Test result: FAIL, response: null, cache: from setTags
 */
- (void)testGetTagsFromMemoryCache {
    
    //Preconditions:
	self.mockRequestManager.failed = YES;
	self.mockRequestManager.response = nil;
	
	NSDictionary *injectedTags = self.injectedTags;
	[self.pushManager setTags:injectedTags];
	
	XCTestExpectation *tagsExpectation = [self expectationWithDescription:@"tags loaded"];
	
    //Steps:
	[self.pushManager loadTags:^(NSDictionary * tags) {
		XCTAssertNotNil(tags, @"Tags are nil");
		XCTAssertTrue([tags isKindOfClass: [NSDictionary class]], @"Tags are not NSDictionary");
		XCTAssertTrue([tags isEqualToDictionary:injectedTags], @"Error: expected tags: (%@) returned tags: (%@)", [NSDictionary new], tags);
		
		[tagsExpectation fulfill];
	} error:^(NSError* e){
		XCTFail (@"Failed to load tags: " );
		[tagsExpectation fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:5 handler:nil];
}

@end
