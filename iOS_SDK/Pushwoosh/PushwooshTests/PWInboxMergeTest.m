#import <XCTest/XCTest.h>

#import "PWInboxMerge.h"
#import "PWInboxStorage.h"
#import "PWInboxMessageInternal.h"
#import "PWInboxMessageInternal+Status.h"

@interface PWInboxMergeTest : XCTestCase

@property (nonatomic, strong) PWInboxMerge *merge;
@property (nonatomic, strong) PWInboxStorage *storage;

@end

@implementation PWInboxMergeTest

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
    _merge = [PWInboxMerge new];
    _storage = [PWInboxStorage new];
    [_storage reset];
}

- (void)tearDown {
    [_storage reset];
    [self.class removeStorageFiles];
    [super tearDown];
}

#pragma mark - Helpers

- (PWInboxMessageInternal *)messageWithCode:(NSString *)code status:(PWInboxMessageStatus)status {
    NSDictionary *dict = @{
        @"inbox_id": code,
        @"order": @1,
        @"rt": @(2000000000),
        @"text": @"hello",
        @"action_type": @0,
        @"status": @(status),
    };
    return [PWInboxMessageInternal messageWithDictionary:dict];
}

#pragma mark - Empty merge

/// Verifies that merging an empty serviceMessages dictionary calls completion with empty arrays.
- (void)testMerge_emptyServiceMessages_completionWithEmptyArrays {
    XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
    __block NSArray *needUpdate;
    __block NSArray *updates;

    [_merge mergeServiceMessages:@{}
                      andStorage:_storage
                      completion:^(NSArray *n, NSArray *u) {
        needUpdate = n;
        updates = u;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(needUpdate.count, 0u);
    XCTAssertEqual(updates.count, 0u);
}

#pragma mark - Status synchronization

/// Verifies that a service message with the same status as the locally stored message is NOT added to either output array.
- (void)testMerge_sameStatus_noUpdatesNeeded {
    PWInboxMessageInternal *local = [self messageWithCode:@"msg-1" status:PWInboxMessageStatusDelivered];
    [_storage updateInboxMessage:local];

    PWInboxMessageInternal *service = [self messageWithCode:@"msg-1" status:PWInboxMessageStatusDelivered];

    XCTestExpectation *expectation = [self expectationWithDescription:@"merge"];
    __block NSArray *needUpdate;
    __block NSArray *updates;

    [_merge mergeServiceMessages:@{@"msg-1": service}
                      andStorage:_storage
                      completion:^(NSArray *n, NSArray *u) {
        needUpdate = n;
        updates = u;
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqual(needUpdate.count, 0u);
    XCTAssertEqual(updates.count, 0u);
}

/// Verifies that when local storage has a higher status (Read) than the service (Delivered), the service message is added to needUpdateStatusMessages — we need to push that status to the server. The service message's status is upgraded to the local one in-place.
- (void)testMerge_localHigherStatus_serviceMessageAppearsInNeedUpdateStatusMessages {
    PWInboxMessageInternal *local = [self messageWithCode:@"msg-1" status:PWInboxMessageStatusRead];
    [_storage updateInboxMessage:local];

    PWInboxMessageInternal *service = [self messageWithCode:@"msg-1" status:PWInboxMessageStatusDelivered];

    XCTestExpectation *expectation = [self expectationWithDescription:@"merge"];
    __block NSArray<PWInboxMessageInternal *> *needUpdate;

    [_merge mergeServiceMessages:@{@"msg-1": service}
                      andStorage:_storage
                      completion:^(NSArray *n, NSArray *u) {
        needUpdate = n;
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqual(needUpdate.count, 1u);
    XCTAssertEqualObjects(needUpdate.firstObject.code, @"msg-1");
    XCTAssertEqual(needUpdate.firstObject.status, PWInboxMessageStatusRead);
}

/// Verifies that a service message for a code that doesn't exist in local storage is NOT added to either output array (new-message handling lives in storage.updateInboxMessagesFromService).
- (void)testMerge_unknownCode_notInAnyOutput {
    PWInboxMessageInternal *service = [self messageWithCode:@"msg-new" status:PWInboxMessageStatusDelivered];

    XCTestExpectation *expectation = [self expectationWithDescription:@"merge"];
    __block NSArray *needUpdate;
    __block NSArray *updates;

    [_merge mergeServiceMessages:@{@"msg-new": service}
                      andStorage:_storage
                      completion:^(NSArray *n, NSArray *u) {
        needUpdate = n;
        updates = u;
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqual(needUpdate.count, 0u);
    XCTAssertEqual(updates.count, 0u);
}

@end
