#import "PWInAppMessagesManager.h"
#import "PWPreferences.h"
#import "PWTriggerInAppActionRequest.h"

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface PWInAppMessagesManager (TEST)

- (void)setUserId:(NSString *)userId completion:(void(^)(NSError * error))completion;
- (void)registerEmailUser:(NSString *)email userId:(NSString *)userId;
+ (NSDictionary *)richMediaDescriptorFrom:(id)rawRichMedia;

@end

@interface PWInAppMessagesManagerTest : XCTestCase

@end

@implementation PWInAppMessagesManagerTest

/// Verifies that setUserId:completion: persists the provided userId into PWPreferences.
- (void)testSetUserId {
    NSString *userId = @"1234567890";
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];

    [manager setUserId:userId completion:^(NSError *error) {}];

    XCTAssertEqualObjects(userId, [PWPreferences preferences].userId);
}

/// Verifies that setUserId:completion: with nil leaves PWPreferences.userId at nil.
- (void)testSetUserIdEqualNil {
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    id mockPWPreference = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPWPreference userId]).andReturn(nil);

    [manager setUserId:nil completion:^(NSError *error) {}];

    XCTAssertNil([PWPreferences preferences].userId);

    [mockPWPreference stopMocking];
}

/// Verifies that registerEmailUser:userId: persists the supplied userId into PWPreferences.
- (void)testRegisterEmailUserWithUserNotNil {
    NSString *userId = @"1234567890";
    NSString *email = @"test@test.com";
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];

    [manager registerEmailUser:email userId:userId];

    XCTAssertEqualObjects(userId, [PWPreferences preferences].userId);
}

/// Verifies that trackInAppWithCode for a rich-media code (r- prefix) extracts the richMediaCode and leaves inAppCode empty.
- (void)testRichMedia {
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    PWTriggerInAppActionRequest *request = [PWTriggerInAppActionRequest new];
    id mockPWTriggerInAppActionRequest = OCMClassMock([PWTriggerInAppActionRequest class]);
    OCMStub([mockPWTriggerInAppActionRequest new]).andReturn(request);

    [manager trackInAppWithCode:@"r-XXXXX-XXXX5" action:@"action" messageHash:@"__xczafasdadgsdf"];

    XCTAssertEqualObjects(request.inAppCode, @"");
    XCTAssertEqualObjects(request.messageHash, @"__xczafasdadgsdf");
    XCTAssertEqualObjects(request.richMediaCode, @"XXXXX-XXXX5");

    [mockPWTriggerInAppActionRequest stopMocking];
}

/// Verifies that trackInAppWithCode for a regular in-app code routes the code into inAppCode and leaves richMediaCode nil.
- (void)testOpenInApp {
    PWInAppMessagesManager *manager = [[PWInAppMessagesManager alloc] init];
    PWTriggerInAppActionRequest *request = [PWTriggerInAppActionRequest new];
    id mockPWTriggerInAppActionRequest = OCMClassMock([PWTriggerInAppActionRequest class]);
    OCMStub([mockPWTriggerInAppActionRequest new]).andReturn(request);

    [manager trackInAppWithCode:@"12345-67890" action:@"action" messageHash:@""];

    XCTAssertEqualObjects(request.inAppCode, @"12345-67890");
    XCTAssertEqualObjects(request.messageHash, @"");
    XCTAssertNil(request.richMediaCode);

    [mockPWTriggerInAppActionRequest stopMocking];
}

#pragma mark - richMediaDescriptorFrom

/// Verifies that a dictionary rm value is returned unchanged.
- (void)testRichMediaDescriptorFrom_dictionary_returnsSameDictionary {
    NSDictionary *rm = @{ @"url" : @"https://richmedia.pushwoosh.com/0/6/06883-1BC29.zip", @"ts" : @"1784034924" };

    NSDictionary *result = [PWInAppMessagesManager richMediaDescriptorFrom:rm];

    XCTAssertEqualObjects(result, rm);
}

/// Verifies that a zip URL string with a ts query item becomes a descriptor carrying that ts.
- (void)testRichMediaDescriptorFrom_urlStringWithTs_returnsDescriptorWithTs {
    NSString *url = @"https://richmedia.pushwoosh.com/0/6/06883-1BC29.zip?ts=1784034924";

    NSDictionary *result = [PWInAppMessagesManager richMediaDescriptorFrom:url];

    XCTAssertEqualObjects(result, (@{ @"url" : url, @"ts" : @"1784034924" }));
}

/// Verifies that a zip URL string without a ts query item gets ts "0".
- (void)testRichMediaDescriptorFrom_urlStringWithoutTs_returnsDescriptorWithZeroTs {
    NSString *url = @"https://richmedia.pushwoosh.com/0/6/06883-1BC29.zip";

    NSDictionary *result = [PWInAppMessagesManager richMediaDescriptorFrom:url];

    XCTAssertEqualObjects(result, (@{ @"url" : url, @"ts" : @"0" }));
}

/// Verifies that a JSON object string is parsed into a dictionary.
- (void)testRichMediaDescriptorFrom_jsonString_returnsParsedDictionary {
    NSString *json = @"{\"url\":\"https://richmedia.pushwoosh.com/0/6/06883-1BC29.zip\",\"ts\":\"1784034924\"}";

    NSDictionary *result = [PWInAppMessagesManager richMediaDescriptorFrom:json];

    XCTAssertEqualObjects(result, (@{ @"url" : @"https://richmedia.pushwoosh.com/0/6/06883-1BC29.zip", @"ts" : @"1784034924" }));
}

/// Verifies that a string without a host is returned as-is so the caller's type check rejects it.
- (void)testRichMediaDescriptorFrom_nonUrlString_returnsSameString {
    NSString *raw = @"not-a-url";

    id result = [PWInAppMessagesManager richMediaDescriptorFrom:raw];

    XCTAssertEqualObjects(result, raw);
}

/// Verifies that nil input yields nil.
- (void)testRichMediaDescriptorFrom_nil_returnsNil {
    XCTAssertNil([PWInAppMessagesManager richMediaDescriptorFrom:nil]);
}

@end
