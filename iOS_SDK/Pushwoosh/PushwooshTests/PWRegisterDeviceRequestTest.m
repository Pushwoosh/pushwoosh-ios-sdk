
#import "PWRegisterDeviceRequest.h"
#import "PWPreferences.h"
#import "PWInteractivePush.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"
#import "PWNotificationCategoryBuilder.h"
#import "PushwooshFramework.h"

#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import <OCMock/OCMock.h>

#import <XCTest/XCTest.h>
#import "PWBaseRequestTest.h"

@interface PWRegisterDeviceRequestTest : PWBaseRequestTest

@property (nonatomic, strong) Class originalCategoryBuilder;

@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;

@property (nonatomic) PWRegisterDeviceRequest *request;

@end

@implementation PWRegisterDeviceRequestTest

- (void)setUp {
    [super setUp];
	
	self.originalCategoryBuilder = [PWPlatformModule module].NotificationCategoryBuilder;
	[PWPlatformModule module].NotificationCategoryBuilder = [PWNotificationCategoryBuilder class];
	
	self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
	[PWPlatformModule module].notificationManagerCompat = mock([PWNotificationManagerCompat class]);
}

- (void)tearDown {
	[PWPlatformModule module].NotificationCategoryBuilder = self.originalCategoryBuilder;
	[PWPlatformModule module].notificationManagerCompat = self.originalNotificationManager;
	
	[PWPreferences preferences].categories = nil;
    [super tearDown];
}

- (void)testMethodName {
	_request = [PWRegisterDeviceRequest new];
	XCTAssertEqualObjects([_request methodName], @"registerDevice");
}

// valid categories are tested in CategoriesTest.m

- (void)testNoCategories {
    NSDictionary *response = [self responseFromString:@"{ }"];
	
	PWRegisterDeviceRequest *request = [PWRegisterDeviceRequest new];
	
	[self assertNilOrEmptyArray:[PWPreferences preferences].categories];
	
	[request parseResponse:response];
	
	[self assertNilOrEmptyArray:[PWPreferences preferences].categories];
}

- (void)testNullCategories {
    NSDictionary *response = [self responseFromString:@"{ \"iosCategories\" : null}"];
	
	PWRegisterDeviceRequest *request = [PWRegisterDeviceRequest new];
	
	[self assertNilOrEmptyArray:[PWPreferences preferences].categories];
	
	[request parseResponse:response];
	
	[self assertNilOrEmptyArray:[PWPreferences preferences].categories];
}

- (void)testBadCategoryType {
    NSDictionary *response = [self responseFromString:@"{ \"iosCategories\" : [42]}"];
	
	PWRegisterDeviceRequest *request = [PWRegisterDeviceRequest new];
	
	[self assertNilOrEmptyArray:[PWPreferences preferences].categories];
	
	[request parseResponse:response];
}

- (void)testNullCategoryId {
    NSDictionary *response = [self responseFromString:@"{ \"iosCategories\" : [ { \"categoryId\" : null, \"buttons\" : [ { \"id\" : 0, \"label\" : \"Todo\", \"type\" : \"0\", \"startApplication\" : 0 }, { \"id\" : 1, \"label\": \"Or not to do\", \"type\": \"1\", \"startApplication\" : 0 } ] } ] }"];

	PWRegisterDeviceRequest *request = [PWRegisterDeviceRequest new];
	
	[self assertNilOrEmptyArray:[PWPreferences preferences].categories];
	
	[request parseResponse:response];
	
	[self assertNilOrEmptyArray:[PWPreferences preferences].categories];
}

- (void)assertNilOrEmptyArray:(NSArray*)array {
	if (array) {
		XCTAssertTrue([array isKindOfClass:[NSArray class]]);
	}
	XCTAssertTrue(array == nil || [array count] == 0);
}

- (void)assertNilOrEmptySet:(NSSet*)set {
	if (set) {
		XCTAssertTrue([set isKindOfClass:[NSSet class]]);
	}
	XCTAssertTrue(set == nil || [set count] == 0);
}

@end
