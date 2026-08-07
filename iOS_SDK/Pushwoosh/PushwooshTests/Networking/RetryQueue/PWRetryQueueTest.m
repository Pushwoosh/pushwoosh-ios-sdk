#import <XCTest/XCTest.h>
#import "PWRetryQueue.h"
#import "PWRetryEntry.h"
#import "PWRetryPolicy.h"
#import "PWRetryQueueStorage.h"
#import "PWRetryTransport.h"
#import "PWRequest.h"
#import "PWRequest+Internal.h"
#import "PWPreferences.h"

@interface PinnedPayloadRequest : PWRequest
@end

@implementation PinnedPayloadRequest
- (NSString *)methodName { return @"pushStat"; }
- (NSDictionary *)requestDictionary { return [self baseDictionary]; }
@end

typedef NS_ENUM(NSInteger, FakeMode) {
    FakeModeSuccess,
    FakeModeTransientFail,
    FakeModePermanentFail,
    FakeModeHang,
};

@interface FakeRetryTransport : NSObject <PWRetryTransport>
@property (nonatomic) FakeMode mode;
@property (nonatomic) NSMutableArray<NSString *> *sentIdentifiers;
@property (nonatomic) NSMutableArray<NSString *> *sentBaseUrls;
@property (nonatomic, copy) NSString *currentUrl;
@end

@implementation FakeRetryTransport
- (instancetype)init {
    if (self = [super init]) {
        _sentIdentifiers = [NSMutableArray array];
        _sentBaseUrls = [NSMutableArray array];
        _mode = FakeModeHang;
    }
    return self;
}
- (NSString *)currentBaseUrlForRetry {
    return self.currentUrl;
}
- (void)sendRetryEntry:(PWRetryEntry *)entry completion:(void (^)(NSInteger, NSError *))completion {
    [self.sentIdentifiers addObject:entry.requestIdentifier];
    [self.sentBaseUrls addObject:entry.baseUrl ?: @""];
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
@property (nonatomic, copy) NSString *savedAppCode;
@property (nonatomic, copy) NSDictionary *savedRecord;
@end

@implementation PWRetryQueueTest

- (void)setUp {
    self.transport = [FakeRetryTransport new];
    NSString *name = [NSString stringWithFormat:@"PWRetryQueueTest-%@", [[NSUUID UUID] UUIDString]];
    self.fileURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:name];
    PWRetryQueueStorage *storage = [[PWRetryQueueStorage alloc] initWithFileURL:self.fileURL];
    PWRetryPolicy *policy = [PWRetryPolicy new];
    self.queue = [[PWRetryQueue alloc] initWithTransport:self.transport policy:policy storage:storage];

    self.savedAppCode = [[PWPreferences preferences].appCode copy];
    self.savedRecord = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_ACTIVE_APPLICATION"] copy];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [PWPreferences preferences].appCode = self.savedAppCode;
    [[PWPreferences preferences] updateBaseUrl:[[PWPreferences preferences] defaultBaseUrl]];

    if (self.savedRecord) {
        [[NSUserDefaults standardUserDefaults] setObject:self.savedRecord forKey:@"Pushwoosh_ACTIVE_APPLICATION"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)seedActiveApplicationRecordWithAppCode:(NSString *)appCode baseUrl:(NSString *)baseUrl {
    [[NSUserDefaults standardUserDefaults] setObject:@{ @"appCode": appCode, @"baseUrl": baseUrl }
                                              forKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [PWPreferences preferences].appCode = appCode;
    [[PWPreferences preferences] updateBaseUrl:baseUrl];
}

- (PWRequest *)requestPinnedToAppCode:(NSString *)appCode baseUrl:(NSString *)baseUrl {
    PWRequest *request = [PinnedPayloadRequest new];
    request.pinnedAppCode = appCode;
    request.pinnedBaseUrl = baseUrl;
    return request;
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

#pragma mark - SDK-882: cross-application isolation

/// Verifies an entry frozen with another application's code is dropped instead of replayed once an application has been selected at runtime.
- (void)testStaleEntryIsDroppedWhenApplicationChanged {
    [self seedActiveApplicationRecordWithAppCode:@"BBBBB-22222" baseUrl:@"https://region-b.example.com/json/1.3/"];
    self.transport.currentUrl = @"https://region-b.example.com/json/1.3/";
    self.transport.mode = FakeModeSuccess;

    PWRequest *request = [self requestPinnedToAppCode:@"AAAAA-11111" baseUrl:@"https://region-b.example.com/json/1.3/"];
    [self.queue enqueueRequest:request baseUrl:@"https://region-b.example.com/json/1.3/"];
    [self drain];

    XCTAssertEqual([self entryCount], 0u);
    XCTAssertEqual(self.transport.sentIdentifiers.count, 0u);
}

/// Verifies an entry of the current application whose frozen host was rotated is replayed against the current host instead of being dropped.
- (void)testEntryIsReplayedAgainstTheCurrentHostWhenOnlyTheBaseUrlChanged {
    [self seedActiveApplicationRecordWithAppCode:@"AAAAA-11111" baseUrl:@"https://region-a-moved.example.com/json/1.3/"];
    self.transport.currentUrl = @"https://region-a-moved.example.com/json/1.3/";
    self.transport.mode = FakeModeSuccess;

    PWRequest *request = [self requestPinnedToAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"];
    [self.queue enqueueRequest:request baseUrl:@"https://region-a.example.com/json/1.3/"];
    [self drain];

    XCTAssertEqual(self.transport.sentIdentifiers.count, 1u);
    XCTAssertEqualObjects(self.transport.sentBaseUrls.firstObject, @"https://region-a-moved.example.com/json/1.3/");
    XCTAssertEqual([self entryCount], 0u);
}

/// Verifies a server-side host rotation of the same application keeps every queued statistics event.
- (void)testHostRotationOfTheSameApplicationPreservesTheQueue {
    [self seedActiveApplicationRecordWithAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"];
    self.transport.currentUrl = @"https://region-a.example.com/json/1.3/";
    self.transport.mode = FakeModeHang;

    [self.queue enqueueRequest:[self requestPinnedToAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"]
                       baseUrl:@"https://region-a.example.com/json/1.3/"];
    [self.queue enqueueRequest:[self requestPinnedToAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"]
                       baseUrl:@"https://region-a.example.com/json/1.3/"];
    [self drain];
    XCTAssertEqual([self entryCount], 2u);

    self.transport.currentUrl = @"https://region-a-shard2.example.com/json/1.3/";
    [[PWPreferences preferences] updateBaseUrl:@"https://region-a-shard2.example.com/json/1.3/"];
    [self.queue flush];
    [self drain];

    XCTAssertEqual([self entryCount], 2u, @"a rotation of the same application must not drop its queued events");
}

/// Verifies the staleness check is inert without an active-application record — legacy entries are always replayed.
- (void)testEntryIsKeptWhenNoActiveApplicationRecord {
    self.transport.currentUrl = @"https://region-b.example.com/json/1.3/";
    self.transport.mode = FakeModeHang;

    PWRequest *request = [self requestPinnedToAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"];
    [self.queue enqueueRequest:request baseUrl:@"https://region-a.example.com/json/1.3/"];
    [self drain];

    XCTAssertEqual([self entryCount], 1u);
    XCTAssertEqual(self.transport.sentIdentifiers.count, 1u);
}

/// Verifies purgeAllEntriesWithReason: empties the in-memory queue and the persisted queue.
- (void)testPurgeAllEntriesClearsQueueAndStorage {
    self.transport.mode = FakeModeHang;
    [self.queue enqueueRequest:[[PWRequest alloc] init]];
    [self.queue enqueueRequest:[[PWRequest alloc] init]];
    [self drain];
    XCTAssertEqual([self entryCount], 2u);

    [self.queue purgeAllEntriesWithReason:@"active application changed"];
    [self drain];

    XCTAssertEqual([self entryCount], 0u);
    PWRetryQueueStorage *storage = [[PWRetryQueueStorage alloc] initWithFileURL:self.fileURL];
    XCTAssertEqual([storage loadEntries].count, 0u);
}

/// Verifies a surviving unregister is dropped unsent once the device is back in the application it names.
- (void)testSurvivingUnregisterIsDroppedWhenTheDeviceReturnsToItsApplication {
    [self seedActiveApplicationRecordWithAppCode:@"AAAAA-11111" baseUrl:@"https://region-a.example.com/json/1.3/"];
    self.transport.currentUrl = @"https://region-a.example.com/json/1.3/";
    self.transport.mode = FakeModeSuccess;

    PWRequest *request = [self requestPinnedToAppCode:@"AAAAA-11111" baseUrl:@"https://region-a-old.example.com/json/1.3/"];
    request.survivesApplicationChange = YES;
    [self.queue enqueueRequest:request baseUrl:@"https://region-a-old.example.com/json/1.3/"];
    [self drain];

    XCTAssertEqual([self entryCount], 0u);
    XCTAssertEqual(self.transport.sentIdentifiers.count, 0u);
}

/// Verifies the survivor drop also applies without an active-application record (legacy setAppCode: path).
- (void)testSurvivingUnregisterIsDroppedOnReturnWithoutARecord {
    [PWPreferences preferences].appCode = @"AAAAA-11111";
    self.transport.currentUrl = @"https://region-a.example.com/json/1.3/";
    self.transport.mode = FakeModeSuccess;

    PWRequest *request = [self requestPinnedToAppCode:@"AAAAA-11111" baseUrl:@"https://region-a-old.example.com/json/1.3/"];
    request.survivesApplicationChange = YES;
    [self.queue enqueueRequest:request baseUrl:@"https://region-a-old.example.com/json/1.3/"];
    [self drain];

    XCTAssertEqual([self entryCount], 0u);
    XCTAssertEqual(self.transport.sentIdentifiers.count, 0u);
}

@end
