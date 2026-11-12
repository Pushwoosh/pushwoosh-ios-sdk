#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWRetryQueue.h"
#import "PWRetryEntry.h"
#import "PWRetryPolicy.h"
#import "PWRetryQueueStorage.h"
#import "PWRetryTransport.h"
#import "PWRequest.h"
#import "PWRequest+Internal.h"
#import "PWPreferences.h"
#import "PWConfig.h"
#import "PWTrackInlineEventRequest.h"
#import "PWUtils.common.h"

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
    FakeModeOffline,
    FakeModeConnectionLost,
};

@interface FakeRetryTransport : NSObject <PWRetryTransport>
@property (nonatomic) FakeMode mode;
@property (nonatomic) NSMutableArray<NSString *> *sentIdentifiers;
@property (nonatomic) NSMutableArray<NSString *> *sentBaseUrls;
@property (nonatomic, copy) NSString *currentUrl;
@property (nonatomic) BOOL notReady;
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
- (BOOL)isReadyForRetry {
    return !self.notReady;
}
- (void)sendRetryEntry:(PWRetryEntry *)entry completion:(void (^)(NSInteger, NSError *))completion {
    if (self.notReady) {
        completion(0, [NSError errorWithDomain:PWErrorDomain code:PWErrorRequestNotReady userInfo:nil]);
        return;
    }
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
        case FakeModeOffline:
            completion(0, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]); break;
        case FakeModeConnectionLost:
            completion(0, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil]); break;
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
@property (nonatomic, strong) id configMock;
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
    self.configMock = OCMPartialMock([PWConfig config]);
    OCMStub([self.configMock inlineUrl]).andReturn(@"https://inline.example.com/api/");
}

- (void)tearDown {
    [self.configMock stopMocking];
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

- (void)drainQueue:(PWRetryQueue *)queue {
    for (int i = 0; i < 6; i++) {
        dispatch_sync(queue.serialQueue, ^{});
    }
}

- (PWRequest *)inlineEvent {
    PWRequest *request = [[PWTrackInlineEventRequest alloc] initWithEvent:@{ @"eventId": [[NSUUID UUID] UUIDString], @"type": @"show" }];
    request.pinnedAppCode = @"AAAAA-11111";
    return request;
}

- (NSArray<PWRetryEntry *> *)queuedEntries {
    __block NSArray *entries = nil;
    dispatch_sync(self.queue.serialQueue, ^{ entries = [self.queue.entries copy]; });
    return entries;
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

#pragma mark - Inline events

/// Verifies an inline event sent without network keeps its attempts and leaves as soon as the network is back.
- (void)testOfflineInlineEventWaitsForNetworkWithoutSpendingAttempts {
    self.transport.mode = FakeModeOffline;
    PWRequest *event = [self inlineEvent];
    [self.queue enqueueRequest:event];
    [self drain];
    for (int i = 0; i < 4; i++) {
        [self.queue onNetworkReachable];
        [self drain];
    }

    XCTAssertEqual([self entryCount], 1u);
    XCTAssertEqual([self queuedEntries].firstObject.attemptCount, 0u);

    self.transport.mode = FakeModeSuccess;
    [self.queue onNetworkReachable];
    [self drain];

    XCTAssertEqual([self entryCount], 0u);
    XCTAssertEqualObjects(self.transport.sentIdentifiers.lastObject, event.requestIdentifier);
}

/// Verifies an inline event whose connection dropped mid-request is retried with a growing attempt count, not parked.
- (void)testInlineEventWithLostConnectionSpendsAttempt {
    self.transport.mode = FakeModeConnectionLost;
    [self.queue enqueueRequest:[self inlineEvent]];
    [self drain];

    XCTAssertEqual([self entryCount], 1u);
    XCTAssertEqual([self queuedEntries].firstObject.attemptCount, 1u);
    XCTAssertFalse([self queuedEntries].firstObject.awaitingNetwork);
}

/// Verifies a request the queue delivers is announced with its method and body.
- (void)testDeliveredEntryIsAnnounced {
    self.transport.mode = FakeModeSuccess;
    XCTestExpectation *announced = [self expectationForNotification:PWRetryQueueDidDeliverRequestNotification object:self.queue handler:^BOOL(NSNotification *note) {
        return [note.userInfo[PWRetryQueueMethodNameKey] isEqualToString:@"trackInlineEvent"] && [note.userInfo[PWRetryQueueBodyKey][@"type"] isEqualToString:@"show"];
    }];

    [self.queue enqueueRequest:[self inlineEvent]];
    [self drain];

    [self waitForExpectations:@[announced] timeout:1.0];
}

/// Verifies a delivered request of a method that does not ask for it is not announced.
- (void)testDeliveredEntryOfOtherMethodIsNotAnnounced {
    self.transport.mode = FakeModeSuccess;
    XCTestExpectation *announced = [self expectationForNotification:PWRetryQueueDidDeliverRequestNotification object:self.queue handler:nil];
    announced.inverted = YES;

    [self.queue enqueueRequest:[PinnedPayloadRequest new]];
    [self drain];

    [self waitForExpectations:@[announced] timeout:0.5];
    XCTAssertEqual(self.transport.sentIdentifiers.count, 1u);
}

/// Verifies an inline event queued before a relaunch is still announced when the next launch delivers it.
- (void)testInlineEventDeliveredAfterRelaunchIsAnnounced {
    self.transport.mode = FakeModeOffline;
    [self.queue enqueueRequest:[self inlineEvent]];
    [self drain];

    FakeRetryTransport *relaunched = [FakeRetryTransport new];
    relaunched.mode = FakeModeSuccess;
    PWRetryQueue *queue = [[PWRetryQueue alloc] initWithTransport:relaunched
                                                           policy:[PWRetryPolicy new]
                                                          storage:[[PWRetryQueueStorage alloc] initWithFileURL:self.fileURL]];
    XCTestExpectation *announced = [self expectationForNotification:PWRetryQueueDidDeliverRequestNotification object:queue handler:^BOOL(NSNotification *note) {
        return [note.userInfo[PWRetryQueueMethodNameKey] isEqualToString:@"trackInlineEvent"];
    }];
    [self drainQueue:queue];

    [self waitForExpectations:@[announced] timeout:1.0];
}

/// Verifies an inline event left unsent without network goes out on the next launch.
- (void)testOfflineInlineEventIsSentOnNextLaunch {
    self.transport.mode = FakeModeOffline;
    PWRequest *event = [self inlineEvent];
    [self.queue enqueueRequest:event];
    [self drain];

    FakeRetryTransport *relaunched = [FakeRetryTransport new];
    relaunched.mode = FakeModeSuccess;
    PWRetryQueue *queue = [[PWRetryQueue alloc] initWithTransport:relaunched
                                                           policy:[PWRetryPolicy new]
                                                          storage:[[PWRetryQueueStorage alloc] initWithFileURL:self.fileURL]];
    [self drainQueue:queue];

    XCTAssertEqualObjects(relaunched.sentIdentifiers, @[event.requestIdentifier]);
    XCTAssertEqualObjects(relaunched.sentBaseUrls, @[@"https://inline.example.com/api/"]);
}

/// Verifies an inline event woken on launch before the SDK is ready keeps its attempts and leaves on the flush after readiness.
- (void)testInlineEventWokenBeforeReadinessLeavesOnTheReadyFlush {
    self.transport.mode = FakeModeOffline;
    PWRequest *event = [self inlineEvent];
    [self.queue enqueueRequest:event];
    [self drain];

    FakeRetryTransport *relaunched = [FakeRetryTransport new];
    relaunched.mode = FakeModeSuccess;
    relaunched.notReady = YES;
    PWRetryQueue *queue = [[PWRetryQueue alloc] initWithTransport:relaunched
                                                           policy:[PWRetryPolicy new]
                                                          storage:[[PWRetryQueueStorage alloc] initWithFileURL:self.fileURL]];
    [self drainQueue:queue];

    __block PWRetryEntry *held = nil;
    dispatch_sync(queue.serialQueue, ^{ held = [queue.entries firstObject]; });
    XCTAssertEqual(held.attemptCount, 0u);

    relaunched.notReady = NO;
    [queue flush];
    [self drainQueue:queue];

    XCTAssertEqualObjects(relaunched.sentIdentifiers, @[event.requestIdentifier]);
}

/// Verifies a regular request without network still spends an attempt and waits for its backoff.
- (void)testOfflineRegularRequestSpendsAttemptAsBefore {
    self.transport.mode = FakeModeOffline;
    [self.queue enqueueRequest:[[PWRequest alloc] init]];
    [self drain];
    [self.queue onNetworkReachable];
    [self drain];

    XCTAssertEqual(self.transport.sentIdentifiers.count, 1u);
    XCTAssertEqual([self queuedEntries].firstObject.attemptCount, 1u);
}

/// Verifies an inline event is replayed on its own host, not on the moved host of the application.
- (void)testInlineEventKeepsItsHostWhenTheApplicationHostMoved {
    [self seedActiveApplicationRecordWithAppCode:@"AAAAA-11111" baseUrl:@"https://region-a-moved.example.com/json/1.3/"];
    self.transport.currentUrl = @"https://region-a-moved.example.com/json/1.3/";
    self.transport.mode = FakeModeSuccess;

    [self.queue enqueueRequest:[self inlineEvent] baseUrl:@"https://inline.example.com/api/"];
    [self drain];

    XCTAssertEqualObjects(self.transport.sentBaseUrls, @[@"https://inline.example.com/api/"]);
    XCTAssertEqual([self entryCount], 0u);
}

/// Verifies that at most 100 inline events stay queued, the oldest are dropped and other requests are kept.
- (void)testInlineEventsAreCappedAtHundredDroppingTheOldest {
    self.transport.mode = FakeModeOffline;
    PWRequest *regular = [[PWRequest alloc] init];
    [self.queue enqueueRequest:regular];
    NSMutableArray<NSString *> *events = [NSMutableArray array];
    for (int i = 0; i < 101; i++) {
        PWRequest *event = [self inlineEvent];
        [events addObject:event.requestIdentifier];
        [self.queue enqueueRequest:event];
    }
    [self drain];

    NSArray *queued = [[self queuedEntries] valueForKey:@"requestIdentifier"];
    XCTAssertEqual(queued.count, 101u);
    XCTAssertTrue([queued containsObject:regular.requestIdentifier]);
    XCTAssertFalse([queued containsObject:events.firstObject]);
    XCTAssertTrue([queued containsObject:events.lastObject]);
}

@end
