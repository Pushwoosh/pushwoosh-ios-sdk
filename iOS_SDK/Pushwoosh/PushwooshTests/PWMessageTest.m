//
//  PWMessageTest.m
//  PushwooshTests
//
//  Created by André Kis on 29.10.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <PushwooshFramework/PushwooshFramework.h>

@interface PWMessageTest : XCTestCase

@end

@interface PWMessage (TEST)

- (instancetype)initWithPayload:(NSDictionary *)payload foreground:(BOOL)foreground;

@end

@implementation PWMessageTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testPayloadHasNoHash {
    uint64_t expectedMessageid = 0;
    uint64_t expectedCampaignId = 0;
    NSString *expectedMessageCode = @"";
    
    PWMessage *message = [[PWMessage alloc] initWithPayload:@{} foreground:NO];
    
    XCTAssertEqual(expectedMessageid, message.messageId);
    XCTAssertEqual(expectedCampaignId, message.campaignId);
    XCTAssertEqualObjects(expectedMessageCode, message.messageCode);
}

- (void)testPayloadWithValidHash {
    NSString *messageHash = @"_1C__000-000000-000000";
    NSDictionary *payload = @{@"p" : messageHash};
    uint64_t expectedMessageid = 0;
    uint64_t expectedCampaignId = 100;
    NSString *expectedMessageCode = @"0000-00000000-00000000";
    
    PWMessage *message = [[PWMessage alloc] initWithPayload:payload foreground:NO];

    XCTAssertEqualObjects(expectedMessageCode, message.messageCode);
    XCTAssertEqual(expectedMessageid, message.messageId);
    XCTAssertEqual(expectedCampaignId, message.campaignId);
}

@end
