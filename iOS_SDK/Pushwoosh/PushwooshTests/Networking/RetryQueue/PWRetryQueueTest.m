#import <XCTest/XCTest.h>
#import "PWRetryQueue.h"
#import "PWRetryEntry.h"
#import "PWRetryPolicy.h"
#import "PWRetryQueueStorage.h"
#import "PWRetryTransport.h"
#import "PWRequest.h"

typedef NS_ENUM(NSInteger, FakeMode) {
    FakeModeSuccess,
    FakeModeTransientFail,
    FakeModePermanentFail,
    FakeModeHang,
};

@interface FakeRetryTransport : NSObject <PWRetryTransport>
@property (nonatomic) FakeMode mode;
@property (nonatomic) NSMutableArray<NSString *> *sentIdentifiers;
@end

@implementation FakeRetryTransport
- (instancetype)init {
    if (self = [super init]) { _sentIdentifiers = [NSMutableArray array]; _mode = FakeModeHang; }
    return self;
}
- (void)sendRetryEntry:(PWRetryEntry *)entry completion:(void (^)(NSInteger, NSError *))completion {
    [self.sentIdentifiers addObject:entry.requestIdentifier];
    switch (self.mode) {
        case FakeModeSuccess:
            completion(200, nil); break;
        case FakeModeTransientFail:
            completion(500, [NSError errorWithDomain:@"t" code:500 userInfo:nil]); break;
        case FakeModePermanentFail:
            completion(400, [NSError errorWithDomain:@"t" code:400 userInfo:nil]); break;
        case FakeModeHang:
            break;
    }
}
@end

@interface PWRetryQueue (Test)
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableArray *entries;
@end

@interface PWRetryQueueTest : XCTestCase
@property (nonatomic) FakeRetryTransport *transport;
@property (nonatomic) PWRetryQueue *queue;
@property (nonatomic) NSURL *fileURL;
@end

@implementation PWRetryQueueTest

- (void)setUp {
    self.transport = [FakeRetryTransport new];
    NSString *name = [NSString stringWithFormat:@"PWRetryQueueTest-%@", [[NSUUID UUID] UUIDString]];
    self.fileURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:name];
    PWRetryQueueStorage *storage = [[PWRetryQueueStorage alloc] initWithFileURL:self.fileURL];
    PWRetryPolicy *policy = [PWRetryPolicy new];
    self.queue = [[PWRetryQueue alloc] initWithTransport:self.transport policy:policy storage:storage];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];
}

- (void)drain {
    for (int i = 0; i < 6; i++) {
        dispatch_sync(self.queue.serialQueue, ^{});
    }
}

- (NSUInteger)entryCount {
    __block NSUInteger c = 0;
    dispatch_sync(self.queue.serialQueue, ^{ c = self.queue.entries.count; });
    return c;
}

/// Verifies a successful send removes the entry from the queue.
- (void)testFlushSuccess_removesEntry {
    self.transport.mode = FakeModeSuccess;
    [self.queue enqueueRequest:[[PWRequest alloc] init]];
    [self drain];

    XCTAssertEqual(self.transport.sentIdentifiers.count, 1u);
    XCTAssertEqual([self entryCount], 0u);
}

/// Verifies a transient failure keeps the entry and increments its attempt count.
- (void)testTransientFail_keepsAndIncrements {
    self.transport.mode = FakeModeTransientFail;
    [self.queue enqueueRequest:[[PWRequest alloc] init]];
    [self drain];

    XCTAssertEqual([self entryCount], 1u);
    __block NSUInteger attempt = 0;
    dispatch_sync(self.queue.serialQueue, ^{ attempt = [self.queue.entries.firstObject attemptCount]; });
    XCTAssertEqual(attempt, 1u);
}

/// Verifies a permanent (4xx) failure drops the entry without further retries.
- (void)testPermanentFail_dropsEntry {
    self.transport.mode = FakeModePermanentFail;
    [self.queue enqueueRequest:[[PWRequest alloc] init]];
    [self drain];

    XCTAssertEqual([self entryCount], 0u);
}

/// Verifies enqueueing the same request twice produces only one queued entry.
- (void)testEnqueueDuplicate_singleEntry {
    self.transport.mode = FakeModeHang;
    PWRequest *request = [[PWRequest alloc] init];
    [self.queue enqueueRequest:request];
    [self.queue enqueueRequest:request];
    [self drain];

    XCTAssertEqual([self entryCount], 1u);
    XCTAssertEqual(self.transport.sentIdentifiers.count, 1u);
}

/// Verifies an in-flight entry is not sent again by a concurrent flush (no double-send).
- (void)testInFlightDedup_noDoubleSend {
    self.transport.mode = FakeModeHang;
    [self.queue enqueueRequest:[[PWRequest alloc] init]];
    [self drain];
    [self.queue flush];
    [self.queue flush];
    [self drain];

    XCTAssertEqual(self.transport.sentIdentifiers.count, 1u);
}

@end
