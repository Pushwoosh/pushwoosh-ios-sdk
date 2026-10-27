//  PWInboxTabsStorageTest.m
//  Created by André Kis

#import <XCTest/XCTest.h>

#import "PWInboxStorage.h"
#import "PWInboxTabs.h"

@interface PWInboxStorage (Test)

- (BOOL)saveTabsPayload:(nullable NSDictionary *)payload;

@end

@interface PWInboxTabsStorageTest : XCTestCase

@property (nonatomic, strong) PWInboxStorage *storage;

@end

@implementation PWInboxTabsStorageTest

+ (void)removeStorageFiles {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths.firstObject;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"PWInbox.serviceMessages"] error:nil];
    [fm removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"PWInbox.pushNotificationMessages"] error:nil];
    NSString *tabsPath = [documentsDirectory stringByAppendingPathComponent:@"PWInbox.tabs"];
    [fm setAttributes:@{NSFileImmutable: @NO} ofItemAtPath:tabsPath error:nil];
    [fm removeItemAtPath:tabsPath error:nil];
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

- (NSString *)tabsFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths.firstObject;
    return [documentsDirectory stringByAppendingPathComponent:@"PWInbox.tabs"];
}

#pragma mark - updateTabsFromPayload / tabs

/// Verifies that a parsed tab list is served from memory after a payload write.
- (void)testWritePayloadExposesParsedTabs {
    NSDictionary *payload = @{@"all_title": @"All", @"tabs": @[@{@"id": @"a", @"title": @"Bills"}]};
    [_storage updateTabsFromPayload:payload];
    XCTAssertEqualObjects(_storage.tabs.allTitle, @"All");
    XCTAssertEqual(_storage.tabs.tabs.count, 1);
}

/// Verifies that each write replaces the whole list and that nil clears it.
- (void)testWriteReplacesWholeListAndNilClears {
    NSDictionary *payloadA = @{@"all_title": @"A", @"tabs": @[@{@"id": @"a", @"title": @"A"}]};
    NSDictionary *payloadB = @{@"all_title": @"B", @"tabs": @[@{@"id": @"b", @"title": @"B"}]};
    [_storage updateTabsFromPayload:payloadA];
    [_storage updateTabsFromPayload:payloadB];
    XCTAssertEqual(_storage.tabs.tabs.count, 1);
    XCTAssertEqualObjects(_storage.tabs.tabs[0].identifier, @"b");
    [_storage updateTabsFromPayload:nil];
    XCTAssertNil(_storage.tabs);
}

/// Verifies that a fresh storage instance over the same files serves the last written list.
- (void)testListSurvivesProcessRestart {
    NSDictionary *payload = @{@"all_title": @"All", @"tabs": @[@{@"id": @"a", @"title": @"Bills"}]};
    [_storage updateTabsFromPayload:payload];
    PWInboxStorage *restarted = [PWInboxStorage new];
    XCTAssertEqualObjects(restarted.tabs, _storage.tabs);
}

/// Verifies that reset drops the cached list (this is what covers an app code change and a user id change).
- (void)testResetClearsTabs {
    NSDictionary *payload = @{@"all_title": @"All", @"tabs": @[@{@"id": @"a", @"title": @"Bills"}]};
    [_storage updateTabsFromPayload:payload];
    [_storage reset];
    XCTAssertNil(_storage.tabs);
    XCTAssertNil([PWInboxStorage new].tabs);
}

/// Verifies that an unchanged tab list is not rewritten to disk, while a changed one is.
- (void)testEqualPayloadDoesNotRewriteTheCacheFile {
    NSDictionary *payload = @{@"all_title": @"All", @"tabs": @[@{@"id": @"a", @"title": @"Bills"}]};
    [_storage updateTabsFromPayload:payload];
    NSFileManager *fm = [NSFileManager defaultManager];
    XCTAssertTrue([fm removeItemAtPath:[self tabsFilePath] error:nil]);

    [_storage updateTabsFromPayload:@{@"all_title": @"All", @"tabs": @[@{@"id": @"a", @"title": @"Bills"}]}];

    XCTAssertFalse([fm fileExistsAtPath:[self tabsFilePath]]);
    XCTAssertEqualObjects(_storage.tabs.tabs.firstObject.identifier, @"a");

    [_storage updateTabsFromPayload:@{@"all_title": @"All", @"tabs": @[@{@"id": @"b", @"title": @"Promos"}]}];

    XCTAssertTrue([fm fileExistsAtPath:[self tabsFilePath]]);
    XCTAssertEqualObjects(_storage.tabs.tabs.firstObject.identifier, @"b");
}

/// Verifies that clearing the tabs cache reports whether the file really went away.
- (void)testClearingTheCacheReportsAFailedFileRemoval {
    NSDictionary *payload = @{@"all_title": @"A", @"tabs": @[@{@"id": @"a", @"title": @"A"}]};
    [_storage updateTabsFromPayload:payload];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [self tabsFilePath];
    XCTAssertTrue([fm setAttributes:@{NSFileImmutable: @YES} ofItemAtPath:path error:nil]);

    XCTAssertFalse([_storage saveTabsPayload:nil]);
    XCTAssertTrue([fm fileExistsAtPath:path]);

    XCTAssertTrue([fm setAttributes:@{NSFileImmutable: @NO} ofItemAtPath:path error:nil]);
    XCTAssertTrue([_storage saveTabsPayload:nil]);
    XCTAssertFalse([fm fileExistsAtPath:path]);
    XCTAssertTrue([_storage saveTabsPayload:nil]);
}

/// Verifies that a cache the storage failed to clear keeps the in-memory list.
- (void)testFailedCacheRemovalKeepsTheInMemoryList {
    NSDictionary *payload = @{@"all_title": @"A", @"tabs": @[@{@"id": @"a", @"title": @"A"}]};
    [_storage updateTabsFromPayload:payload];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [self tabsFilePath];
    XCTAssertTrue([fm setAttributes:@{NSFileImmutable: @YES} ofItemAtPath:path error:nil]);

    [_storage updateTabsFromPayload:nil];

    XCTAssertEqualObjects(_storage.tabs.tabs.firstObject.identifier, @"a");
    XCTAssertEqualObjects([PWInboxStorage new].tabs, _storage.tabs);

    XCTAssertTrue([fm setAttributes:@{NSFileImmutable: @NO} ofItemAtPath:path error:nil]);
}

/// Verifies that a corrupt tabs file leaves no tabs and does not block message loading.
- (void)testCorruptTabsFileIsIgnored {
    [@"not an archive" writeToFile:[self tabsFilePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    PWInboxStorage *storage = [PWInboxStorage new];
    XCTAssertNil(storage.tabs);
    XCTAssertNoThrow([storage getAllMessages]);
}

/// Verifies that concurrent reads during writes neither crash nor hand back a partial list.
- (void)testConcurrentReadsDuringWrites {
    NSDictionary *payloadA = @{@"all_title": @"A", @"tabs": @[@{@"id": @"a", @"title": @"A"}]};
    NSDictionary *payloadB = @{@"all_title": @"B", @"tabs": @[@{@"id": @"b", @"title": @"B"}]};

    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
    dispatch_apply(200, queue, ^(size_t i) {
        if (i % 2 == 0) {
            [self->_storage updateTabsFromPayload:(i % 4 == 0) ? payloadA : payloadB];
        } else {
            PWInboxTabs *tabs = self->_storage.tabs;
            if (tabs != nil) {
                XCTAssertEqual(tabs.tabs.count, 1u);
                NSString *identifier = tabs.tabs.firstObject.identifier;
                XCTAssertTrue([identifier isEqualToString:@"a"] || [identifier isEqualToString:@"b"]);
            }
        }
    });
}

@end
