
#import "PWRegisterDeviceRequest.h"
#import "PWPreferences.h"
#import "PWInteractivePush.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"
#import "PWNotificationCategoryBuilder.h"
#import "PushwooshFramework.h"
#import "PWPushNotificationsManager.common.h"

#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import <OCMock/OCMock.h>

#import <XCTest/XCTest.h>
#import "PWBaseRequestTest.h"

@interface PWRegisterDeviceRequestTest : PWBaseRequestTest

@property (nonatomic, strong) Class originalCategoryBuilder;

@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;

@property (nonatomic) PWRegisterDeviceRequest *requestDevice;

@property (nonatomic) PWPushNotificationsManagerCommon *notificationManager;

@end

@interface PWPushNotificationsManagerCommon (TEST)

@property (nonatomic) PWRegisterDeviceRequest *request;

@end

@interface PWRegisterDeviceRequest (TEST)

- (NSDictionary *)requestDictionary;

@end

@implementation PWRegisterDeviceRequestTest

- (void)setUp {
    [super setUp];
	
    self.notificationManager = [[PWPushNotificationsManagerCommon alloc] init];
    
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

/// Verifies that PWRegisterDeviceRequest reports the "registerDevice" method name.
- (void)testMethodName {
    _requestDevice = [PWRegisterDeviceRequest new];
    XCTAssertEqualObjects([_requestDevice methodName], @"registerDevice");
}

/// Verifies that an empty response leaves preferences.categories nil/empty.
- (void)testNoCategories {
    NSDictionary *response = [self responseFromString:@"{ }"];
    PWRegisterDeviceRequest *request = [PWRegisterDeviceRequest new];

    [self assertNilOrEmptyArray:[PWPreferences preferences].categories];
    [request parseResponse:response];
    [self assertNilOrEmptyArray:[PWPreferences preferences].categories];
}

/// Verifies that a null iosCategories response leaves preferences.categories nil/empty.
- (void)testNullCategories {
    NSDictionary *response = [self responseFromString:@"{ \"iosCategories\" : null}"];
    PWRegisterDeviceRequest *request = [PWRegisterDeviceRequest new];

    [self assertNilOrEmptyArray:[PWPreferences preferences].categories];
    [request parseResponse:response];
    [self assertNilOrEmptyArray:[PWPreferences preferences].categories];
}

/// Verifies that a numeric (non-object) category entry in iosCategories does not crash and is ignored.
- (void)testBadCategoryType {
    NSDictionary *response = [self responseFromString:@"{ \"iosCategories\" : [42]}"];
    PWRegisterDeviceRequest *request = [PWRegisterDeviceRequest new];

    [self assertNilOrEmptyArray:[PWPreferences preferences].categories];
    [request parseResponse:response];
}

/// Verifies that a category entry with null categoryId is rejected and categories remain empty.
- (void)testNullCategoryId {
    NSDictionary *response = [self responseFromString:@"{ \"iosCategories\" : [ { \"categoryId\" : null, \"buttons\" : [ { \"id\" : 0, \"label\" : \"Todo\", \"type\" : \"0\", \"startApplication\" : 0 }, { \"id\" : 1, \"label\": \"Or not to do\", \"type\": \"1\", \"startApplication\" : 0 } ] } ] }"];
    PWRegisterDeviceRequest *request = [PWRegisterDeviceRequest new];

    [self assertNilOrEmptyArray:[PWPreferences preferences].categories];
    [request parseResponse:response];
    [self assertNilOrEmptyArray:[PWPreferences preferences].categories];
}

- (void)assertNilOrEmptyArray:(NSArray *)array {
    if (array) {
        XCTAssertTrue([array isKindOfClass:[NSArray class]]);
    }
    XCTAssertTrue(array == nil || [array count] == 0);
}

/// Verifies that registerSmsNumber sets the request platform to SMS (18) and stores the token.
- (void)testRegisterSmsNumberWithCorrectParameters {
    NSInteger SMS = 18;
    NSString *expectedTokenSms = @"+sms_token";
    _notificationManager = [[PWPushNotificationsManagerCommon alloc] init];

    [_notificationManager registerSmsNumber:expectedTokenSms];

    XCTAssertEqual(_notificationManager.request.platform, SMS);
    XCTAssertEqualObjects(_notificationManager.request.token, expectedTokenSms);
}

/// Verifies that registerWhatsappNumber sets the request platform to WhatsApp (21) and stores the token.
- (void)testRegisterWhatsappWithCorrectParameters {
    NSInteger whatsapp = 21;
    NSString *expectedTokenWhatsapp = @"+whatsapp_token";

    [_notificationManager registerWhatsappNumber:expectedTokenWhatsapp];

    XCTAssertEqual(_notificationManager.request.platform, whatsapp);
    XCTAssertEqualObjects(_notificationManager.request.token, expectedTokenWhatsapp);
}

/// Verifies that for the SMS platform, the request dictionary carries the raw token in both push_token and hwid.
- (void)testRequestDicitionaryPlatformSms {
    NSString *expectedToken = @"+sms_token";
    NSInteger SMS = 18;
    _requestDevice = [PWRegisterDeviceRequest new];
    _requestDevice.token = expectedToken;
    _requestDevice.platform = SMS;

    XCTAssertEqualObjects(_requestDevice.requestDictionary[@"push_token"], expectedToken);
    XCTAssertEqualObjects(_requestDevice.requestDictionary[@"hwid"], expectedToken);
}

/// Verifies that for the WhatsApp platform, push_token and hwid are prefixed with "whatsapp:".
- (void)testRequestDicitionaryPlatformWhatsapp {
    NSString *expectedToken = @"+whatsapp_token";
    NSInteger whatsapp = 21;
    NSString *whatsappToken = [@"whatsapp:" stringByAppendingString:expectedToken];
    _requestDevice = [PWRegisterDeviceRequest new];
    _requestDevice.token = expectedToken;
    _requestDevice.platform = whatsapp;

    XCTAssertEqualObjects(_requestDevice.requestDictionary[@"push_token"], whatsappToken);
    XCTAssertEqualObjects(_requestDevice.requestDictionary[@"hwid"], whatsappToken);
}

@end
