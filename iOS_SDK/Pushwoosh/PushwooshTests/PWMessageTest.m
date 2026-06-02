#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <PushwooshFramework/PushwooshFramework.h>

@interface PWMessageTest : XCTestCase

@end

@interface PWMessage (TEST)

- (instancetype)initWithPayload:(NSDictionary *)payload foreground:(BOOL)foreground;

@end

@implementation PWMessageTest

/// Verifies that a payload without a "p" key produces a PWMessage with zero ids and an empty messageCode.
- (void)testPayloadHasNoHash {
    PWMessage *message = [[PWMessage alloc] initWithPayload:@{} foreground:NO];

    XCTAssertEqual(message.messageId, 0);
    XCTAssertEqual(message.campaignId, 0);
    XCTAssertEqualObjects(message.messageCode, @"");
}

/// Verifies that a "_<campaign>_<message>_<code>" hash in the "p" key populates campaignId and messageCode.
- (void)testPayloadWithValidHash {
    NSDictionary *payload = @{@"p" : @"_1C__000-000000-000000"};

    PWMessage *message = [[PWMessage alloc] initWithPayload:payload foreground:NO];

    XCTAssertEqualObjects(message.messageCode, @"0000-00000000-00000000");
    XCTAssertEqual(message.messageId, 0);
    XCTAssertEqual(message.campaignId, 100);
}

@end
