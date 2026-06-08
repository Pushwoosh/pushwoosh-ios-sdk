#import <XCTest/XCTest.h>
#import "PWRetryQueue.h"
#import "PWRetryEntry.h"
#import "PWRetryPolicy.h"
#import "PWRetryQueueStorage.h"
#import "PWRetryTransport.h"
#import "PWRequest.h"

@interface ScriptedRetryTransport : NSObject <PWRetryTransport>
@property (nonatomic, copy) NSArray<NSNumber *> *statusCodes;
@property (nonatomic, assign) BOOL hang;
@property (nonatomic, assign) NSUInteger callCount;
@property (nonatomic, strong) NSMutableArray<NSString *> *sentIdentifiers;
@end

@implementation ScriptedRetryTransport

- (instancetype)init {
    if (self = [super init]) {
        _sentIdentifiers = [NSMutableArray array];
        _statusCodes = @[@500];
    }
    return self;
}

- (void)sendRetryEntry:(PWRetryEntry *)entry completion:(void (^)(NSInteger, NSError *))completion {
    [self.sentIdentifiers addObject:entry.requestIdentifier];
    NSUInteger index = MIN(self.callCount, self.statusCodes.count - 1);
    self.callCount++;
    if (self.hang) {
        return;
    }
    NSInteger code = self.statusCodes[index].integerValue;
    if (code >= 200 && code < 300) {
        completion(code, nil);
    } else {
        completion(code, [NSError errorWithDomain:@"integration" code:code userInfo:nil]);
    }
}

@end

@interface PWRetryQueue (Integration)
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableArray *entries;
@end

@interface PWRetryQueueIntegrationTest : XCTestCase
@property (nonatomic) ScriptedRetryTransport *transport;
@property (nonatomic) PWRetryQueue *queue;
@property (nonatomic) NSURL *fileURL;
@end

@implementation PWRetryQueueIntegrationTest

- (void)setUp {
    self.transport = [ScriptedRetryTransport new];
    self.fileURL = [self freshFileURL];
    self.queue = [self queueWithPolicy:[self fastPolicy] transport:self.transport fileURL:self.fileURL];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];
}

#pragma mark - Helpers

- (NSURL *)freshFileURL {
    NSString *name = [NSString stringWithFormat:@"PWRetryQueueIntegration-%@", [[NSUUID UUID] UUIDString]];
    return [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:name];
}

- (PWRetryPolicy *)fastPolicy {
    PWRetryPolicy *policy = [PWRetryPolicy new];
    policy.baseDelay = 0.01;
    policy.minDelay = 0.01;
    policy.maxDelay = 0.05;
    policy.jitterFraction = 0;
    policy.maxAttempts = 4;
    policy.timeToLive = 3 * 24 * 60 * 60;
    return policy;
}

- (PWRetryQueue *)queueWithPolicy:(PWRetryPolicy *)policy transport:(id<PWRetryTransport>)transport fileURL:(NSURL *)url {
    PWRetryQueueStorage *storage = [[PWRetryQueueStorage alloc] initWithFileURL:url];
    return [[PWRetryQueue alloc] initWithTransport:transport policy:policy storage:storage];
}

- (NSUInteger)inMemoryCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.queue.serialQueue, ^{ count = self.queue.entries.count; });
    return count;
}

- (NSUInteger)diskCountAt:(NSURL *)url {
    PWRetryQueueStorage *fresh = [[PWRetryQueueStorage alloc] initWithFileURL:url];
    return [fresh loadEntries].count;
}

- (BOOL)waitUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!condition() && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return condition();
}

- (void)spinRunLoop:(NSTimeInterval)seconds {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

#pragma mark - Tests

/// Integration: a successful send removes the entry from both the in-memory queue and disk — nothing left behind.
- (void)testSuccess_removesFromQueueAndDisk {
    self.transport.statusCodes = @[@200];
    [self.queue enqueueRequest:[PWRequest new]];

    XCTAssertTrue([self waitUntil:^BOOL { return [self inMemoryCount] == 0; } timeout:2]);
    XCTAssertEqual(self.transport.callCount, 1u);
    XCTAssertEqual([self diskCountAt:self.fileURL], 0u);
}

/// Integration: transient failures across several backoff cycles eventually succeed, then the entry is removed everywhere.
- (void)testRetriesAcrossBackoffsThenSucceeds {
    self.transport.statusCodes = @[@500, @503, @500, @200];
    [self.queue enqueueRequest:[PWRequest new]];

    XCTAssertTrue([self waitUntil:^BOOL { return [self inMemoryCount] == 0; } timeout:3]);
    XCTAssertEqual(self.transport.callCount, 4u);
    XCTAssertEqual([self diskCountAt:self.fileURL], 0u);
}

/// Integration: a request that always fails transiently is dropped after maxAttempts — it does NOT accumulate forever.
- (void)testExhaustion_dropsAfterMaxAttempts {
    self.transport.statusCodes = @[@500];
    [self.queue enqueueRequest:[PWRequest new]];

    XCTAssertTrue([self waitUntil:^BOOL { return [self inMemoryCount] == 0; } timeout:3]);
    XCTAssertEqual(self.transport.callCount, 4u);
    XCTAssertEqual([self diskCountAt:self.fileURL], 0u);
}

/// Integration: a permanent (4xx) failure is dropped immediately from queue and disk, with no retry.
- (void)testPermanentFailure_removesImmediately {
    self.transport.statusCodes = @[@400];
    [self.queue enqueueRequest:[PWRequest new]];

    XCTAssertTrue([self waitUntil:^BOOL { return [self inMemoryCount] == 0; } timeout:2]);
    XCTAssertEqual(self.transport.callCount, 1u);
    XCTAssertEqual([self diskCountAt:self.fileURL], 0u);
}

/// Integration: a stale entry past its TTL is dropped on the next flush instead of being retried — it does not linger.
- (void)testTTLExpiry_dropsStaleEntryWithoutRetry {
    PWRetryPolicy *policy = [PWRetryPolicy new];
    policy.baseDelay = 10;
    policy.minDelay = 10;
    policy.maxDelay = 10;
    policy.jitterFraction = 0;
    policy.maxAttempts = 8;
    policy.timeToLive = 0.1;
    self.queue = [self queueWithPolicy:policy transport:self.transport fileURL:self.fileURL];
    self.transport.statusCodes = @[@500];

    [self.queue enqueueRequest:[PWRequest new]];
    [self spinRunLoop:0.25];
    [self.queue flush];

    XCTAssertTrue([self waitUntil:^BOOL { return [self inMemoryCount] == 0; } timeout:2]);
    XCTAssertEqual(self.transport.callCount, 1u);
    XCTAssertEqual([self diskCountAt:self.fileURL], 0u);
}

/// Integration: an entry persisted by one queue survives a "restart" (new queue, same storage), is delivered by it, then removed.
- (void)testSurvivesRestartThenDelivers {
    NSURL *url = [self freshFileURL];

    ScriptedRetryTransport *offline = [ScriptedRetryTransport new];
    offline.hang = YES;
    PWRetryQueue *first = [self queueWithPolicy:[self fastPolicy] transport:offline fileURL:url];
    [first enqueueRequest:[PWRequest new]];
    [self spinRunLoop:0.2];

    XCTAssertEqual([self diskCountAt:url], 1u);
    XCTAssertEqual(offline.callCount, 1u);

    ScriptedRetryTransport *online = [ScriptedRetryTransport new];
    online.statusCodes = @[@200];
    PWRetryQueue *second = [self queueWithPolicy:[self fastPolicy] transport:online fileURL:url];

    XCTAssertTrue([self waitUntil:^BOOL { return [self diskCountAt:url] == 0; } timeout:3]);
    XCTAssertEqual(online.callCount, 1u);

    (void)second;
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
}

/// Integration: many queued requests all drain to empty — the queue does not accumulate when the network is healthy.
- (void)testManyRequests_allDrainToZero {
    self.transport.statusCodes = @[@200];
    for (int i = 0; i < 10; i++) {
        [self.queue enqueueRequest:[PWRequest new]];
    }

    XCTAssertTrue([self waitUntil:^BOOL { return [self inMemoryCount] == 0; } timeout:3]);
    XCTAssertEqual(self.transport.callCount, 10u);
    XCTAssertEqual([self diskCountAt:self.fileURL], 0u);
}

@end
