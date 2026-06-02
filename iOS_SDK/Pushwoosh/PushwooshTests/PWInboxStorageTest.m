#import <XCTest/XCTest.h>

#import "PWInboxStorage.h"
#import "PWInboxMessageInternal.h"
#import "PWInboxMessageInternal+Status.h"

@interface PWInboxStorageTest : XCTestCase

@property (nonatomic, strong) PWInboxStorage *storage;

@end

@implementation PWInboxStorageTest

+ (void)removeStorageFiles {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths.firstObject;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"PWInbox.serviceMessages"] error:nil];
    [fm removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"PWInbox.pushNotificationMessages"] error:nil];
}

- (void)setUp {
    [super setUp];
    [self.class removeStorageFiles];
    _storage = [PWInboxStorage new];
    [_storage reset];
}

- (void)tearDown {
    [_storage reset];
    [self.class removeStorageFiles];
    [super tearDown];
}

#pragma mark - Helpers

- (PWInboxMessageInternal *)messageWithCode:(NSString *)code
                                     status:(PWInboxMessageStatus)status
                                  expiresAt:(NSTimeInterval)expiresAt
                                   sendDate:(NSTimeInterval)sendDate {
    NSDictionary *dict = @{
        @"inbox_id": code,
        @"order": @1,
        @"rt": @(expiresAt),
        @"send_date": @(sendDate),
        @"text": @"hello",
        @"title": @"title",
        @"action_type": @0,
        @"status": @(status),
    };
    return [PWInboxMessageInternal messageWithDictionary:dict];
}

- (PWInboxMessageInternal *)freshMessageWithCode:(NSString *)code status:(PWInboxMessageStatus)status {
    return [self messageWithCode:code status:status expiresAt:2000000000 sendDate:1700000000];
}

#pragma mark - reset

/// Verifies that reset clears all messages and brings count to 0.
- (void)testReset_clearsAllMessages {
    PWInboxMessageInternal *msg = [self freshMessageWithCode:@"msg-1" status:PWInboxMessageStatusDelivered];
    [_storage updateInboxMessage:msg];
    XCTAssertEqual([_storage count], 1);

    [_storage reset];

    XCTAssertEqual([_storage count], 0);
    XCTAssertEqual([_storage getAllMessages].count, 0u);
}

#pragma mark - addInboxMessageFromPushNotification

/// Verifies that addInboxMessageFromPushNotification adds the message to allMessages so messageForCode returns it.
- (void)testAddInboxMessageFromPushNotification_storesByCode {
    PWInboxMessageInternal *msg = [self freshMessageWithCode:@"push-1" status:PWInboxMessageStatusDelivered];

    [_storage addInboxMessageFromPushNotification:msg];

    XCTAssertEqual([_storage count], 1);
    XCTAssertEqual([_storage messageForCode:@"push-1"], msg);
}

#pragma mark - updateInboxMessage

/// Verifies that updateInboxMessage stores a service-side message so messageForCode returns it.
- (void)testUpdateInboxMessage_storesServiceMessage {
    PWInboxMessageInternal *msg = [self freshMessageWithCode:@"srv-1" status:PWInboxMessageStatusDelivered];

    [_storage updateInboxMessage:msg];

    XCTAssertEqual([_storage messageForCode:@"srv-1"], msg);
}

#pragma mark - updateInboxMessagesFromService

/// Verifies that updateInboxMessagesFromService with brand new messages reports them in messagesAdded.
- (void)testUpdateInboxMessagesFromService_newMessages_reportedAsAdded {
    PWInboxMessageInternal *m1 = [self freshMessageWithCode:@"srv-1" status:PWInboxMessageStatusDelivered];
    PWInboxMessageInternal *m2 = [self freshMessageWithCode:@"srv-2" status:PWInboxMessageStatusDelivered];

    XCTestExpectation *expectation = [self expectationWithDescription:@"update"];
    __block NSArray *added;
    __block NSArray *deleted;

    [_storage updateInboxMessagesFromService:@{@"srv-1": m1, @"srv-2": m2}
                                  completion:^(NSArray *needUpdate, NSArray *del, NSArray *add, NSArray *upd) {
        added = add;
        deleted = del;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(added.count, 2u);
    XCTAssertEqual(deleted.count, 0u);
    XCTAssertEqual([_storage count], 2);
}

/// Verifies that updateInboxMessagesFromService with a smaller set than previously persisted reports the missing codes as messagesDeleted.
- (void)testUpdateInboxMessagesFromService_missingFromNewSet_reportedAsDeleted {
    PWInboxMessageInternal *m1 = [self freshMessageWithCode:@"srv-1" status:PWInboxMessageStatusDelivered];
    PWInboxMessageInternal *m2 = [self freshMessageWithCode:@"srv-2" status:PWInboxMessageStatusDelivered];

    XCTestExpectation *firstUpdate = [self expectationWithDescription:@"first"];
    [_storage updateInboxMessagesFromService:@{@"srv-1": m1, @"srv-2": m2}
                                  completion:^(NSArray *n, NSArray *d, NSArray *a, NSArray *u) {
        [firstUpdate fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTestExpectation *secondUpdate = [self expectationWithDescription:@"second"];
    __block NSArray<NSString *> *deleted = nil;
    [_storage updateInboxMessagesFromService:@{@"srv-1": m1}
                                  completion:^(NSArray *n, NSArray *d, NSArray *a, NSArray *u) {
        deleted = d;
        [secondUpdate fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqual(deleted.count, 1u);
    XCTAssertEqualObjects(deleted.firstObject, @"srv-2");
}

#pragma mark - updateStatus:withInboxMessageCodes:

/// Verifies that updateStatus persists the new status on each message identified by code, returning updated messages.
- (void)testUpdateStatus_persistsAndReturnsUpdatedMessages {
    PWInboxMessageInternal *m1 = [self freshMessageWithCode:@"srv-1" status:PWInboxMessageStatusDelivered];
    [_storage updateInboxMessage:m1];

    NSArray<PWInboxMessageInternal *> *updated = [_storage updateStatus:PWInboxMessageStatusRead
                                                  withInboxMessageCodes:@[@"srv-1"]];

    XCTAssertEqual(updated.count, 1u);
    XCTAssertEqual([_storage messageForCode:@"srv-1"].status, PWInboxMessageStatusRead);
}

/// Verifies that updateStatus to the same status is a no-op (does not include the message in the returned array).
- (void)testUpdateStatus_sameStatus_returnsEmpty {
    PWInboxMessageInternal *m1 = [self freshMessageWithCode:@"srv-1" status:PWInboxMessageStatusRead];
    [_storage updateInboxMessage:m1];

    NSArray<PWInboxMessageInternal *> *updated = [_storage updateStatus:PWInboxMessageStatusRead
                                                  withInboxMessageCodes:@[@"srv-1"]];

    XCTAssertEqual(updated.count, 0u);
}

#pragma mark - getAllMessages

/// Verifies that getAllMessages excludes messages whose status is Deleted.
- (void)testGetAllMessages_excludesDeleted {
    PWInboxMessageInternal *m1 = [self freshMessageWithCode:@"srv-1" status:PWInboxMessageStatusDelivered];
    PWInboxMessageInternal *m2 = [self freshMessageWithCode:@"srv-2" status:PWInboxMessageStatusDeleted];
    [_storage updateInboxMessage:m1];
    [_storage updateInboxMessage:m2];

    NSArray<PWInboxMessageInternal *> *all = [_storage getAllMessages];

    XCTAssertEqual(all.count, 1u);
    XCTAssertEqualObjects(all.firstObject.code, @"srv-1");
}

/// Verifies that getAllMessages excludes messages whose expiration (rt) is in the past (isExpired).
- (void)testGetAllMessages_excludesExpired {
    NSTimeInterval longAgo = 1;
    PWInboxMessageInternal *expired = [self messageWithCode:@"old-1" status:PWInboxMessageStatusDelivered expiresAt:longAgo sendDate:longAgo];
    PWInboxMessageInternal *fresh = [self freshMessageWithCode:@"new-1" status:PWInboxMessageStatusDelivered];
    [_storage updateInboxMessage:expired];
    [_storage updateInboxMessage:fresh];

    NSArray<PWInboxMessageInternal *> *all = [_storage getAllMessages];

    XCTAssertEqual(all.count, 1u);
    XCTAssertEqualObjects(all.firstObject.code, @"new-1");
}

/// Verifies that getAllMessages sorts by sendDate descending (most recent first).
- (void)testGetAllMessages_sortedBySendDateDescending {
    PWInboxMessageInternal *older = [self messageWithCode:@"a" status:PWInboxMessageStatusDelivered expiresAt:2000000000 sendDate:1000000000];
    PWInboxMessageInternal *newer = [self messageWithCode:@"b" status:PWInboxMessageStatusDelivered expiresAt:2000000000 sendDate:1900000000];
    [_storage updateInboxMessage:older];
    [_storage updateInboxMessage:newer];

    NSArray<PWInboxMessageInternal *> *all = [_storage getAllMessages];

    XCTAssertEqual(all.count, 2u);
    XCTAssertEqualObjects(all[0].code, @"b", @"most recent (b) should come first");
    XCTAssertEqualObjects(all[1].code, @"a");
}

#pragma mark - messageForCode / messagesForCodes

/// Verifies that messageForCode returns nil when the code is not present.
- (void)testMessageForCode_missingCode_returnsNil {
    XCTAssertNil([_storage messageForCode:@"nope"]);
}

/// Verifies that messagesForCodes returns only the matching messages and filters out missing entries.
- (void)testMessagesForCodes_returnsOnlyMatches {
    PWInboxMessageInternal *m1 = [self freshMessageWithCode:@"a" status:PWInboxMessageStatusDelivered];
    PWInboxMessageInternal *m2 = [self freshMessageWithCode:@"b" status:PWInboxMessageStatusDelivered];
    [_storage updateInboxMessage:m1];
    [_storage updateInboxMessage:m2];

    NSArray<PWInboxMessageInternal *> *result = [_storage messagesForCodes:@[@"a", @"missing", @"b"]];

    XCTAssertEqual(result.count, 2u);
    NSArray *codes = [result valueForKeyPath:@"code"];
    XCTAssertTrue([codes containsObject:@"a"]);
    XCTAssertTrue([codes containsObject:@"b"]);
}

#pragma mark - Persistence round-trip

/// Verifies that messages persisted by one PWInboxStorage instance are loaded by a fresh instance reading from the same Documents directory.
- (void)testPersistence_savedMessagesAreLoadedByFreshStorageInstance {
    PWInboxMessageInternal *m1 = [self freshMessageWithCode:@"persist-1" status:PWInboxMessageStatusDelivered];
    [_storage updateInboxMessage:m1];

    PWInboxStorage *freshStorage = [PWInboxStorage new];

    XCTAssertEqual([freshStorage count], 1);
    XCTAssertNotNil([freshStorage messageForCode:@"persist-1"]);

    [freshStorage reset];
}

/// Verifies that a message whose action_params JSON resolves to a dictionary containing nested NSArray and NSNull (typical APNS payload shape — loc-args, action arrays, optional NSNull values) round-trips through save/load without dropping the message. Regression for the secure-decode allowlist completeness.
- (void)testPersistence_messageWithNestedArrayAndNSNullInActionParams_roundTrips {
    NSDictionary *dict = @{
        @"inbox_id": @"complex-1",
        @"order": @1,
        @"rt": @(2000000000),
        @"send_date": @(1700000000),
        @"text": @"hello",
        @"action_type": @0,
        @"status": @(PWInboxMessageStatusDelivered),
        @"action_params": @"{\"loc-args\":[\"Anna\",\"Bob\"],\"badge\":42,\"custom\":null}",
    };
    PWInboxMessageInternal *msg = [PWInboxMessageInternal messageWithDictionary:dict];
    XCTAssertNotNil(msg.actionParams[@"loc-args"]);
    [_storage updateInboxMessage:msg];

    PWInboxStorage *freshStorage = [PWInboxStorage new];

    XCTAssertEqual([freshStorage count], 1);
    PWInboxMessageInternal *loaded = [freshStorage messageForCode:@"complex-1"];
    XCTAssertNotNil(loaded);
    XCTAssertTrue([loaded.actionParams[@"loc-args"] isKindOfClass:[NSArray class]]);
    XCTAssertEqual([loaded.actionParams[@"loc-args"] count], 2u);

    [freshStorage reset];
}

#pragma mark - Service vs Push merging priority

/// Verifies that when both a push-notification message AND a service message exist for the same code, updateAllMessages prefers the service one (service messages take priority).
- (void)testUpdateAllMessages_serviceWinsOverPushNotificationForSameCode {
    PWInboxMessageInternal *pushMsg = [self freshMessageWithCode:@"dup" status:PWInboxMessageStatusDelivered];
    PWInboxMessageInternal *serviceMsg = [self freshMessageWithCode:@"dup" status:PWInboxMessageStatusRead];

    [_storage addInboxMessageFromPushNotification:pushMsg];
    [_storage updateInboxMessage:serviceMsg];

    XCTAssertEqual([_storage messageForCode:@"dup"].status, PWInboxMessageStatusRead);
}

@end
