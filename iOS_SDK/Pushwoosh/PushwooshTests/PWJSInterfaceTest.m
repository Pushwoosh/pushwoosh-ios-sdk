
#import <XCTest/XCTest.h>

#import "PWPushwooshJSBridge.h"
#import "PushNotificationManager.h"
#import "PushNotificationManager+Mock.h"
#import "PWRequestManager.h"
#import "PWTestUtils.h"

@interface PWJSInterfaceTest : XCTestCase<PWWebClientDelegate>

@property (nonatomic, strong) PWPushwooshJSBridge *jsInterface;

@property (nonatomic, assign) BOOL closed;

@property (nonatomic, strong) NSDictionary *lastTags;

@property (nonatomic, strong) NSString *lastEvent;

@property (nonatomic, strong) NSDictionary *lastAttributes;

@property (nonatomic) PWWebClient *webClient;

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
}

- (void)tearDown {
    [PushNotificationManager setMock:NO];
	
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
