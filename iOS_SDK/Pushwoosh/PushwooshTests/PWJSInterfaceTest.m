
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWPushwooshJSBridge.h"
#import "PushNotificationManager.h"
#import "PushNotificationManager+Mock.h"
#import "PWRequestManager.h"
#import "PWTestUtils.h"
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PWDataManager.h>

@interface PWJSInterfaceTestDataManagerMock : PWDataManager
@property (nonatomic, weak) id target;
@end

@implementation PWJSInterfaceTestDataManagerMock
- (void)setTags:(NSDictionary *)tags {
    if ([self.target respondsToSelector:@selector(setTags:)]) {
        [self.target performSelector:@selector(setTags:) withObject:tags];
    }
}
@end

@interface PWJSInterfaceTest : XCTestCase<PWWebClientDelegate>

@property (nonatomic, strong) PWPushwooshJSBridge *jsInterface;

@property (nonatomic, assign) BOOL closed;

@property (nonatomic, strong) NSDictionary *lastTags;

@property (nonatomic, strong) NSString *lastEvent;

@property (nonatomic, strong) NSDictionary *lastAttributes;

@property (nonatomic) PWWebClient *webClient;

@property (nonatomic) PWJSInterfaceTestDataManagerMock *mockDataManager;
@property (nonatomic) PWDataManager *originalDataManager;

@end

@implementation PWJSInterfaceTest

- (void)setUp {
    [super setUp];

	[PWTestUtils setUp];

    _webClient = [[PWWebClient alloc] initWithParentView:nil payload:@{} code:@"" inAppCode:@""];
    _webClient.delegate = self;
	self.jsInterface = [[PWPushwooshJSBridge alloc] initWithClient:_webClient];
	self.closed = NO;
	self.lastTags = nil;
	self.lastEvent = nil;
	self.lastAttributes = nil;
	[PushNotificationManager setMock:YES];
	[PushNotificationManager setProxy:self];

	self.originalDataManager = [PWManagerBridge shared].dataManager;
	self.mockDataManager = [[PWJSInterfaceTestDataManagerMock alloc] init];
	self.mockDataManager.target = self;
	[PWManagerBridge shared].dataManager = self.mockDataManager;
}

- (void)tearDown {
    [PushNotificationManager setMock:NO];
	[PWManagerBridge shared].dataManager = self.originalDataManager;
	self.mockDataManager = nil;
	self.originalDataManager = nil;

	[PWTestUtils tearDown];

    [super tearDown];
}

- (void)testSendTags {
	NSString *tags = @"{ \"IntTag\" : 42, \"BoolTag\" : true, \"StringTag\" : \"testString\", \"ListTag\" : [ \"string1\", \"string2\" ] }";
	[_jsInterface performSelector:@selector(sendTags:) withObject:tags];
	NSDictionary *expectedTags = @ { @"IntTag" : @(42), @"BoolTag" : @YES, @"StringTag" : @"testString", @"ListTag" : @[ @"string1", @"string2" ] };
	XCTAssertTrue([self.lastTags isEqualToDictionary:expectedTags], @"Result tags (%@) does not match input (%@)", self.lastTags, expectedTags);
}

- (void)testStressSendTags {
	NSString *tags = @"{ \"IntTag\" : 42, \"BoolTag\" : true, ";
	[_jsInterface performSelector:@selector(sendTags:) withObject:tags];
	XCTAssertNil(self.lastTags);
}

- (void)testSendTagsWithEmptyString {
	NSString *tags = @"{}";
	[_jsInterface performSelector:@selector(sendTags:) withObject:tags];
	XCTAssertNotNil(self.lastTags);
	XCTAssertEqual(self.lastTags.count, 0);
}

- (void)testLog {
	XCTAssertNoThrow([_jsInterface performSelector:@selector(log:) withObject:@"Test log message"]);
}

- (void)testLogWithEmptyString {
	XCTAssertNoThrow([_jsInterface performSelector:@selector(log:) withObject:@""]);
}

- (void)testSetEmail {
	id mockManagerBridge = OCMPartialMock([PWManagerBridge shared]);

	[_jsInterface performSelector:@selector(setEmail:) withObject:@"test@example.com"];

	OCMVerify([mockManagerBridge setEmail:@"test@example.com"]);
	[mockManagerBridge stopMocking];
}

- (void)testRegisterForPushNotifications {
	id mockManagerBridge = OCMPartialMock([PWManagerBridge shared]);

	[_jsInterface performSelector:@selector(registerForPushNotifications)];

	OCMVerify([mockManagerBridge registerForPushNotifications]);
	[mockManagerBridge stopMocking];
}

- (void)testCloseInApp {
	_webClient.inAppCode = @"testInAppCode";
	_webClient.richMediaCode = @"testRichMediaCode";

	XCTAssertNoThrow([_jsInterface performSelector:@selector(closeInApp)]);
	XCTAssertTrue(self.closed);
}

- (void)testMakePurchaseWithIdentifier {
	NSString *identifier = @"com.test.product";

	XCTAssertNoThrow([_jsInterface performSelector:@selector(makePurchaseWithIdentifier:) withObject:identifier]);
}

- (void)testMakePurchaseWithNilIdentifier {
	XCTAssertNoThrow([_jsInterface performSelector:@selector(makePurchaseWithIdentifier:) withObject:nil]);
}

- (void)testInitWithClient {
	PWWebClient *client = [[PWWebClient alloc] initWithParentView:nil payload:@{} code:@"" inAppCode:@""];
	PWPushwooshJSBridge *bridge = [[PWPushwooshJSBridge alloc] initWithClient:client];

	XCTAssertNotNil(bridge);
}

- (void)testInitWithNilClient {
	PWPushwooshJSBridge *bridge = [[PWPushwooshJSBridge alloc] initWithClient:nil];

	XCTAssertNotNil(bridge);
}

- (void)testSendTagsWithNestedObjects {
	NSString *tags = @"{ \"NestedTag\" : { \"key\" : \"value\" } }";
	[_jsInterface performSelector:@selector(sendTags:) withObject:tags];
	NSDictionary *expectedTags = @{ @"NestedTag" : @{ @"key" : @"value" } };
	XCTAssertTrue([self.lastTags isEqualToDictionary:expectedTags]);
}

- (void)testSendTagsWithNullValue {
	NSString *tags = @"{ \"NullTag\" : null }";
	[_jsInterface performSelector:@selector(sendTags:) withObject:tags];
	XCTAssertNotNil(self.lastTags);
	XCTAssertTrue([self.lastTags[@"NullTag"] isKindOfClass:[NSNull class]]);
}

- (void)testSendTagsWithNumericValues {
	NSString *tags = @"{ \"IntTag\" : 42, \"FloatTag\" : 3.14 }";
	[_jsInterface performSelector:@selector(sendTags:) withObject:tags];
	XCTAssertEqual([self.lastTags[@"IntTag"] integerValue], 42);
	XCTAssertEqualWithAccuracy([self.lastTags[@"FloatTag"] doubleValue], 3.14, 0.01);
}

- (void)testSendTagsWithArrayValues {
	NSString *tags = @"{ \"ArrayTag\" : [1, 2, 3] }";
	[_jsInterface performSelector:@selector(sendTags:) withObject:tags];
	NSArray *expected = @[@1, @2, @3];
	XCTAssertTrue([self.lastTags[@"ArrayTag"] isEqualToArray:expected]);
}

- (void)testSendTagsWithUnicodeCharacters {
	NSString *tags = @"{ \"UnicodeTag\" : \"你好世界\" }";
	[_jsInterface performSelector:@selector(sendTags:) withObject:tags];
	XCTAssertEqualObjects(self.lastTags[@"UnicodeTag"], @"你好世界");
}

- (void)testSendTagsWithSpecialCharacters {
	NSString *tags = @"{ \"SpecialTag\" : \"test\\\"quote\\\"\" }";
	[_jsInterface performSelector:@selector(sendTags:) withObject:tags];
	XCTAssertNotNil(self.lastTags[@"SpecialTag"]);
}

- (void)testSendTagsWithEmptyArray {
	NSString *tags = @"{ \"EmptyArrayTag\" : [] }";
	[_jsInterface performSelector:@selector(sendTags:) withObject:tags];
	NSArray *expected = @[];
	XCTAssertTrue([self.lastTags[@"EmptyArrayTag"] isEqualToArray:expected]);
}

// PushManager proxy methods

- (void) postEvent: (NSString*) event withAttributes: (NSDictionary*) attributes completion: (void(^)(NSError* error)) completion {
	self.lastEvent = event;
	self.lastAttributes = attributes;
	if (completion)
		completion(nil);
}

- (void) setTags: (NSDictionary *) tags {
	self.lastTags = tags;
}

// PWWebClientDelegate
- (void)webClientDidFinishLoad:(PWWebClient *)webClient {}

- (void)webClientDidStartClose:(PWWebClient *)webClient {
    _closed = YES;
}

@end
