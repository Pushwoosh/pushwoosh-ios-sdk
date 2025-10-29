#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWRichMedia.h"
#import "PWRichMedia+Internal.h"
#import "PWResource.h"

@interface PWRichMediaTest : XCTestCase

@property (nonatomic, strong) id mockResource;

@end

@implementation PWRichMediaTest

- (void)setUp {
    self.mockResource = OCMClassMock([PWResource class]);
    OCMStub([(PWResource *)self.mockResource code]).andReturn(@"testCode");
    OCMStub([(PWResource *)self.mockResource required]).andReturn(YES);
}

- (void)tearDown {
    [self.mockResource stopMocking];
    self.mockResource = nil;
}

- (void)testInitWithSourceResource {
    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:self.mockResource];

    XCTAssertNotNil(richMedia);
    XCTAssertEqual(richMedia.source, PWRichMediaSourcePush);
    XCTAssertEqualObjects(richMedia.content, @"testCode");
    XCTAssertNil(richMedia.pushPayload);
}

- (void)testInitWithSourceResourcePushPayload {
    NSDictionary *payload = @{@"key": @"value"};
    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:self.mockResource pushPayload:payload];

    XCTAssertNotNil(richMedia);
    XCTAssertEqual(richMedia.source, PWRichMediaSourceInApp);
    XCTAssertEqualObjects(richMedia.content, @"testCode");
    XCTAssertEqualObjects(richMedia.pushPayload, payload);
}

- (void)testContentReturnsResourceCode {
    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:self.mockResource];

    XCTAssertEqualObjects(richMedia.content, @"testCode");
}

- (void)testIsRequiredForPushSource {
    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:self.mockResource];

    XCTAssertTrue(richMedia.isRequired);
}

- (void)testIsRequiredForInAppSourceWhenResourceRequired {
    OCMStub([self.mockResource required]).andReturn(YES);
    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:self.mockResource];

    XCTAssertTrue(richMedia.isRequired);
}

- (void)testIsRequiredForInAppSourceWhenResourceNotRequired {
    id resource = OCMClassMock([PWResource class]);
    OCMStub([(PWResource *)resource code]).andReturn(@"testCode");
    OCMStub([(PWResource *)resource required]).andReturn(NO);

    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:resource];

    XCTAssertFalse(richMedia.isRequired);

    [resource stopMocking];
}

- (void)testPushSourceAlwaysRequired {
    id resource = OCMClassMock([PWResource class]);
    OCMStub([(PWResource *)resource code]).andReturn(@"testCode");
    OCMStub([(PWResource *)resource required]).andReturn(NO);

    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:resource];

    XCTAssertTrue(richMedia.isRequired);

    [resource stopMocking];
}

- (void)testInitWithNilPushPayload {
    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:self.mockResource pushPayload:nil];

    XCTAssertNotNil(richMedia);
    XCTAssertNil(richMedia.pushPayload);
}

- (void)testInitWithEmptyPushPayload {
    NSDictionary *emptyPayload = @{};
    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:self.mockResource pushPayload:emptyPayload];

    XCTAssertNotNil(richMedia);
    XCTAssertEqualObjects(richMedia.pushPayload, emptyPayload);
}

- (void)testInitWithComplexPushPayload {
    NSDictionary *complexPayload = @{
        @"title": @"Test",
        @"body": @"Message",
        @"data": @{
            @"key1": @"value1",
            @"key2": @42
        }
    };
    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:self.mockResource pushPayload:complexPayload];

    XCTAssertEqualObjects(richMedia.pushPayload, complexPayload);
}

- (void)testSourceProperty {
    PWRichMedia *pushRichMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:self.mockResource];
    PWRichMedia *inAppRichMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:self.mockResource];

    XCTAssertEqual(pushRichMedia.source, PWRichMediaSourcePush);
    XCTAssertEqual(inAppRichMedia.source, PWRichMediaSourceInApp);
}

- (void)testContentWithDifferentResourceCodes {
    id resource1 = OCMClassMock([PWResource class]);
    OCMStub([(PWResource *)resource1 code]).andReturn(@"code1");

    id resource2 = OCMClassMock([PWResource class]);
    OCMStub([(PWResource *)resource2 code]).andReturn(@"code2");

    PWRichMedia *richMedia1 = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:resource1];
    PWRichMedia *richMedia2 = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:resource2];

    XCTAssertEqualObjects(richMedia1.content, @"code1");
    XCTAssertEqualObjects(richMedia2.content, @"code2");

    [resource1 stopMocking];
    [resource2 stopMocking];
}

- (void)testContentWithNilResourceCode {
    id resource = OCMClassMock([PWResource class]);
    OCMStub([(PWResource *)resource code]).andReturn(nil);

    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:resource];

    XCTAssertNil(richMedia.content);

    [resource stopMocking];
}

- (void)testContentWithEmptyResourceCode {
    id resource = OCMClassMock([PWResource class]);
    OCMStub([(PWResource *)resource code]).andReturn(@"");

    PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourcePush resource:resource];

    XCTAssertEqualObjects(richMedia.content, @"");

    [resource stopMocking];
}

@end
