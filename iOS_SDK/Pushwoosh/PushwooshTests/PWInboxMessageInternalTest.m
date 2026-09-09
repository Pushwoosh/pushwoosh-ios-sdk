//
//  PWInboxMessageInternalTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 10.03.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import "PWInboxMessageInternal.h"
#import "PWInbox.h"

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface PWInboxMessageInternal (Test)
+ (BOOL)validateDictionary:(NSDictionary *)dictionary;
+ (instancetype)messageWithDictionary:(NSDictionary *)dictionary;
@end

@interface PWInboxMessageInternalTest : XCTestCase

@property (nonatomic) NSString *code;
@property (nonatomic) NSString *imageUrl;
@property (nonatomic) NSNumber *type;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *message;

@end

@implementation PWInboxMessageInternalTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _code = @"ASDF-ASD_ADAS";
    _imageUrl = @"image_url";
    _type = @0;
    _title = @"test";
    _message = @"test";
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testIsFromNotificationTrue {
    PWInboxMessageInternal *internal = [PWInboxMessageInternal messageWithPushNotification:self.parameters];

    XCTAssertEqual(internal.code, @"ASDF-ASD_ADAS");
    XCTAssertEqual(internal.type, 0);
    XCTAssertEqual(internal.imageUrl, _imageUrl);
    XCTAssertEqual(internal.title, _title);
    XCTAssertEqual(internal.message, _message);
    XCTAssertTrue(internal.isFromNotification);
}

- (void)testIsFromNotificationMethod {
    PWInboxMessageInternal *message = [PWInboxMessageInternal messageWithPushNotification:self.parameters];

    BOOL isFromNotification = [PWInboxMessageInternal isFromNotification:message];

    XCTAssertTrue(isFromNotification);
}

/// validateDictionary returns NO for a non-dictionary element instead of crashing on objectForKey:.
- (void)testValidateDictionaryWithNonDictionaryInput_returnsNO {
    NSArray *arrayInput = @[@"not", @"a", @"dict"];
    XCTAssertFalse([PWInboxMessageInternal validateDictionary:(id)arrayInput]);
    XCTAssertFalse([PWInboxMessageInternal validateDictionary:(id)@42]);
    XCTAssertFalse([PWInboxMessageInternal validateDictionary:(id)@"string"]);
}

/// messageWithDictionary returns nil without crashing when a server array yields a non-dictionary element.
- (void)testMessageWithNonDictionaryInput_returnsNil {
    NSArray *arrayInput = @[@1, @2];
    XCTAssertNil([PWInboxMessageInternal messageWithDictionary:(id)arrayInput]);
}

/// A non-string deep link in an inbox push is ignored instead of crashing while the type is derived.
- (void)testMessageWithNonStringLink_doesNotCrash {
    NSMutableDictionary *payload = [[self parameters] mutableCopy];
    payload[@"l"] = @12345;

    PWInboxMessageInternal *message = [PWInboxMessageInternal messageWithPushNotification:payload];

    XCTAssertNotNil(message);
    XCTAssertEqual(message.type, PWInboxMessageTypePlain);
}

/// Non-string action params of a service message are ignored instead of crashing on hasPrefix:.
- (void)testServiceMessageWithNonStringActionParams_doesNotCrash {
    NSDictionary *serviceMessage = @{ @"inbox_id" : _code,
                                      @"order" : @"1",
                                      @"rt" : @"1646917972",
                                      @"text" : @"test",
                                      @"action_type" : _type,
                                      @"status" : @1,
                                      @"action_params" : @"{\"l\": 456, \"attachment\": 123}" };

    PWInboxMessageInternal *message = [PWInboxMessageInternal messageWithDictionary:serviceMessage];

    XCTAssertNotNil(message);
    XCTAssertNil(message.attachmentUrl);
    XCTAssertEqual(message.type, PWInboxMessageTypePlain);
}

- (NSDictionary *)parameters {
    return @{@"pw_inbox": _code,
                                 @"inbox_params": @{@"rt": @"1646917972",
                                                    @"image": _imageUrl,
                                 },
                                 @"aps": @{@"alert": @{@"alert": @"alert",
                                                       @"title": @"test",
                                                       @"body": @"test",
                                 },
                                 },
                                 @"action_type": _type
    };
}

@end
