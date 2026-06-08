#import <XCTest/XCTest.h>
#import "PWRetryQueueStorage.h"
#import "PWRetryEntry.h"

@interface PWRetryQueueStorageTest : XCTestCase
@property (nonatomic) NSURL *fileURL;
@property (nonatomic) PWRetryQueueStorage *storage;
@end

@implementation PWRetryQueueStorageTest

- (void)setUp {
    NSString *name = [NSString stringWithFormat:@"PWRetryQueueTest-%@", [[NSUUID UUID] UUIDString]];
    self.fileURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:name];
    self.storage = [[PWRetryQueueStorage alloc] initWithFileURL:self.fileURL];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];
}

- (PWRetryEntry *)entryWithIdentifier:(NSString *)identifier {
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1000];
    return [[PWRetryEntry alloc] initWithRequestIdentifier:identifier
                                               methodName:@"pushStat"
                                        requestDictionary:@{@"k": @"v"}
                                             attemptCount:1
                                          nextAttemptDate:now
                                        firstEnqueuedDate:now];
}

/// Verifies entries written to disk are read back intact by a fresh storage instance.
- (void)testSaveLoad_roundTrip {
    NSArray *entries = @[[self entryWithIdentifier:@"a"], [self entryWithIdentifier:@"b"]];
    XCTAssertTrue([self.storage saveEntries:entries]);

    PWRetryQueueStorage *fresh = [[PWRetryQueueStorage alloc] initWithFileURL:self.fileURL];
    NSArray<PWRetryEntry *> *loaded = [fresh loadEntries];

    XCTAssertEqual(loaded.count, 2u);
    XCTAssertEqualObjects(loaded.firstObject.requestIdentifier, @"a");
    XCTAssertEqualObjects(loaded.firstObject.methodName, @"pushStat");
    XCTAssertEqual(loaded.firstObject.attemptCount, 1u);
}

/// Verifies loading a non-existent file yields an empty array, not an error.
- (void)testLoad_missingFile_returnsEmpty {
    NSArray *loaded = [self.storage loadEntries];
    XCTAssertNotNil(loaded);
    XCTAssertEqual(loaded.count, 0u);
}

/// Verifies corrupt bytes on disk yield an empty array without throwing.
- (void)testLoad_corruptData_returnsEmpty {
    [@"not a keyed archive" writeToURL:self.fileURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSArray *loaded = [self.storage loadEntries];
    XCTAssertEqual(loaded.count, 0u);
}

/// Verifies deleteStorage removes the backing file.
- (void)testDelete_removesFile {
    [self.storage saveEntries:@[[self entryWithIdentifier:@"a"]]];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path]);

    [self.storage deleteStorage];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path]);
}

@end
