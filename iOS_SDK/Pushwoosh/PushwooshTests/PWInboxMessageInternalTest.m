//
//  PWInboxMessageInternalTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 10.03.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import "PWInboxMessageInternal.h"
#import "PWInbox.h"
#import "PWInboxMessageInternal+Status.h"

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

#pragma mark - canUpdateStatus state machine

/// A freshly created message accepts any status: the ladder starts at Created.
- (void)testCanUpdateStatusFromCreated_allowsAnyStatus {
    XCTAssertTrue([[PWInboxMessageInternal new] canUpdateStatus:PWInboxMessageStatusDelivered]);
    XCTAssertTrue([[PWInboxMessageInternal new] canUpdateStatus:PWInboxMessageStatusRead]);
    XCTAssertTrue([[PWInboxMessageInternal new] canUpdateStatus:PWInboxMessageStatusAction]);
    XCTAssertTrue([[PWInboxMessageInternal new] canUpdateStatus:PWInboxMessageStatusDeleted]);
}

/// Re-applying the status a message already has is rejected, so no request is sent for it.
- (void)testCanUpdateStatusToSameStatus_isRejected {
    XCTAssertFalse([[self messageWithStatus:PWInboxMessageStatusDelivered] canUpdateStatus:PWInboxMessageStatusDelivered]);
    XCTAssertFalse([[self messageWithStatus:PWInboxMessageStatusRead] canUpdateStatus:PWInboxMessageStatusRead]);
    XCTAssertFalse([[self messageWithStatus:PWInboxMessageStatusAction] canUpdateStatus:PWInboxMessageStatusAction]);
    XCTAssertFalse([[self messageWithStatus:PWInboxMessageStatusDeleted] canUpdateStatus:PWInboxMessageStatusDeleted]);
}

/// Delivered moves up the ladder to Read, Action and Deleted.
- (void)testCanUpdateStatusFromDelivered_allowsReadActionDeleted {
    XCTAssertTrue([[self messageWithStatus:PWInboxMessageStatusDelivered] canUpdateStatus:PWInboxMessageStatusRead]);
    XCTAssertTrue([[self messageWithStatus:PWInboxMessageStatusDelivered] canUpdateStatus:PWInboxMessageStatusAction]);
    XCTAssertTrue([[self messageWithStatus:PWInboxMessageStatusDelivered] canUpdateStatus:PWInboxMessageStatusDeleted]);
}

/// Read moves on to Action and Deleted, but never back down to Delivered.
- (void)testCanUpdateStatusFromRead_allowsActionAndDeleted_rejectsDelivered {
    XCTAssertTrue([[self messageWithStatus:PWInboxMessageStatusRead] canUpdateStatus:PWInboxMessageStatusAction]);
    XCTAssertTrue([[self messageWithStatus:PWInboxMessageStatusRead] canUpdateStatus:PWInboxMessageStatusDeleted]);
    XCTAssertFalse([[self messageWithStatus:PWInboxMessageStatusRead] canUpdateStatus:PWInboxMessageStatusDelivered]);
}

/// Action is above Read on the ladder: once the open is reported, Read is no longer sent (SDK-998).
- (void)testCanUpdateStatusFromAction_rejectsReadAndDelivered_allowsDeleted {
    XCTAssertFalse([[self messageWithStatus:PWInboxMessageStatusAction] canUpdateStatus:PWInboxMessageStatusRead]);
    XCTAssertFalse([[self messageWithStatus:PWInboxMessageStatusAction] canUpdateStatus:PWInboxMessageStatusDelivered]);
    XCTAssertTrue([[self messageWithStatus:PWInboxMessageStatusAction] canUpdateStatus:PWInboxMessageStatusDeleted]);
}

/// Deleted is terminal: nothing moves out of it.
- (void)testCanUpdateStatusFromDeleted_rejectsEverything {
    XCTAssertFalse([[self messageWithStatus:PWInboxMessageStatusDeleted] canUpdateStatus:PWInboxMessageStatusDelivered]);
    XCTAssertFalse([[self messageWithStatus:PWInboxMessageStatusDeleted] canUpdateStatus:PWInboxMessageStatusRead]);
    XCTAssertFalse([[self messageWithStatus:PWInboxMessageStatusDeleted] canUpdateStatus:PWInboxMessageStatusAction]);
    XCTAssertFalse([[self messageWithStatus:PWInboxMessageStatusDeleted] canUpdateStatus:PWInboxMessageStatusDeletedService]);
}

/// A message deleted on the service side still accepts the local Deleted status.
- (void)testCanUpdateStatusFromDeletedService_allowsDeleted {
    XCTAssertTrue([[self messageWithStatus:PWInboxMessageStatusDeletedService] canUpdateStatus:PWInboxMessageStatusDeleted]);
}

#pragma mark - updateStatus

/// updateStatus applies an allowed transition and reports YES.
- (void)testUpdateStatusWithAllowedTransition_appliesAndReturnsYES {
    PWInboxMessageInternal *message = [self messageWithStatus:PWInboxMessageStatusDelivered];

    XCTAssertTrue([message updateStatus:PWInboxMessageStatusAction]);
    XCTAssertEqual(message.status, PWInboxMessageStatusAction);
}

/// updateStatus leaves the message untouched and reports NO when the transition is rejected,
/// which is what keeps the Read status out of the request batch after an open was reported.
- (void)testUpdateStatusWithRejectedTransition_keepsStatusAndReturnsNO {
    PWInboxMessageInternal *message = [self messageWithStatus:PWInboxMessageStatusAction];

    XCTAssertFalse([message updateStatus:PWInboxMessageStatusRead]);
    XCTAssertEqual(message.status, PWInboxMessageStatusAction);
}

/// A message with the Action status counts as read for the UI, so the card still turns read
/// when the open is reported instead of the Read status.
- (void)testActionStatus_countsAsReadAndActionPerformed {
    PWInboxMessageInternal *message = [self messageWithStatus:PWInboxMessageStatusAction];

    XCTAssertTrue(message.isRead);
    XCTAssertTrue(message.isActionPerformed);
    XCTAssertFalse(message.deleted);
}

/// The numeric codes sent to the backend are fixed by the API and must not drift with the enum.
- (void)testNetworkStatusCodes_matchBackendContract {
    XCTAssertEqual([PWInboxMessageInternal readStatusForNetwork], 2);
    XCTAssertEqual([PWInboxMessageInternal actionStatusForNetwork], 3);
    XCTAssertEqual([PWInboxMessageInternal deleteStatusForNetwork], 4);
}

- (PWInboxMessageInternal *)messageWithStatus:(PWInboxMessageStatus)status {
    return [PWInboxMessageInternal messageWithDictionary:@{
        @"inbox_id": _code,
        @"order": @1,
        @"rt": @2000000000,
        @"send_date": @1700000000,
        @"text": _message,
        @"title": _title,
        @"action_type": _type,
        @"status": @(status),
    }];
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
