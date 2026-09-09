#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWPreferences.h"
#import "PWConfig.h"
#import "PushwooshConfig.h"
#import "PWManagerBridge.h"
#import "PWPushNotificationsManager.common.h"
#import "PWPushNotificationsManager.h"
#import "PWSessionRetrySender.h"
#import "PWUnregisterDeviceRequest.h"
#import "PWRequest+Internal.h"
#import "PWSdkStateProvider.h"
#import "PWNetworkModule.h"
#import "PWRequestManager.h"
#import "PWRetryQueue.h"
#import "PWRetryEntry.h"
#import "PWRetryPolicy.h"
#import "PWRetryQueueStorage.h"
#import "PWRetryTransport.h"
#import "PWInboxBridge.h"

static NSString *const kRecordKey = @"Pushwoosh_ACTIVE_APPLICATION";
static NSString *const kAppIdKey = @"Pushwoosh_APPID";
static NSString *const kBaseUrlKey = @"Pushwoosh_BASEURL";
static NSString *const kInfoPlistAppIdKey = @"Pushwoosh_INFO_PLIST_APPID";
static NSString *const kTestSuiteName = @"group.com.test.sdk882";

static NSString *const kAppCodeA = @"AAAAA-11111";
static NSString *const kAppCodeB = @"BBBBB-22222";
static NSString *const kAppCodeC = @"CCCCC-33333";
static NSString *const kUrlA = @"https://region-a.example.com/json/1.3/";
static NSString *const kUrlB = @"https://region-b.example.com/json/1.3/";
static NSString *const kUrlC = @"https://region-c.example.com/json/1.3/";
static NSString *const kRotatedUrlB = @"https://region-b-shard2.example.com/json/1.3/";
static NSString *const kEffectiveKey = @"Pushwoosh_EFFECTIVE_APPLICATION";

@interface PWPreferences (SDK882Test)

+ (void)resetCache;
- (void)writeActiveApplicationRecordWithAppCode:(NSString *)appCode baseUrl:(NSString *)baseUrl;
- (void)mirrorEffectiveApplicationIntoAppGroupWithAppCode:(NSString *)appCode baseUrl:(NSString *)baseUrl;
- (BOOL)switchToApplicationWithAppCode:(NSString *)appCode
                               baseUrl:(NSString *)baseUrl
                          previousPair:(NSDictionary<NSString *, NSString *> **)previousPair;

@end

@interface PWPushNotificationsManagerCommon (SDK882Test)

@property (nonatomic, strong) PWSessionRetrySender *sessionRetry;
@property (nonatomic, strong) PWRequestManager *requestManager;

@end

@interface PWRequestManager (SDK882Test)

@property (nonatomic, strong) PWRetryQueue *retryQueue;

@end

@interface PWRetryQueue (SDK882Test)

@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableArray *entries;

@end

@interface SwitchScopedPayloadRequest : PWRequest
@end

@implementation SwitchScopedPayloadRequest
- (NSString *)methodName { return @"pushStat"; }
- (NSDictionary *)requestDictionary { return [self baseDictionary]; }
@end

/// Always answers with a retryable failure, so an entry stays queued across a switch and is attempted
/// again against whatever host the queue addresses it to.
@interface SwitchScopedUnregisterRequest : PWRequest
@end

@implementation SwitchScopedUnregisterRequest
- (NSString *)methodName { return @"unregisterDevice"; }
- (NSDictionary *)requestDictionary { return [self baseDictionary]; }
@end

@interface SwitchScopedRetryTransport : NSObject <PWRetryTransport>
@property (nonatomic, copy) NSString *currentUrl;
@property (nonatomic, strong) NSObject *recordLock;
@property (nonatomic, strong) NSMutableArray<NSString *> *sentBaseUrls;
@end

@implementation SwitchScopedRetryTransport

- (instancetype)init {
    if (self = [super init]) {
        _sentBaseUrls = [NSMutableArray array];
        _recordLock = [NSObject new];
    }
    return self;
}

- (NSString *)currentBaseUrlForRetry {
    return self.currentUrl;
}

- (void)sendRetryEntry:(PWRetryEntry *)entry completion:(void (^)(NSInteger, NSError *))completion {
    @synchronized (self.recordLock) {
        [self.sentBaseUrls addObject:entry.baseUrl ?: @""];
    }
    completion(500, [NSError errorWithDomain:@"sdk882" code:500 userInfo:nil]);
}

- (NSArray<NSString *> *)recordedBaseUrls {
    @synchronized (self.recordLock) {
        return [self.sentBaseUrls copy];
    }
}

@end


/// Records `resetApplication`, the call that wipes an application's inbox. `inboxBridge` is a
/// `Class<PWInboxBridge>`, so a real class is needed here rather than a protocol mock.
/// `resetHook` runs inside that call, so a test can inspect what the SDK holds while the reset is in
/// progress - the real one archives two files to disk there.
@interface SwitchInboxSpy : NSObject <PWInboxBridge>
+ (void)setResetHook:(void (^_Nullable)(void))hook;
@end


/// Observes the `appCode` key path and runs a block from the notification, standing in for the three
/// production observers of that key path.
@interface SwitchAppCodeObserver : NSObject
@property (nonatomic, copy) void (^onChange)(void);
@property (nonatomic, assign) NSUInteger changeCount;
@end

@implementation SwitchAppCodeObserver

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    if (![keyPath isEqualToString:@"appCode"]) {
        return;
    }
    _changeCount++;
    if (self.onChange) {
        self.onChange();
    }
}

@end

@implementation SwitchInboxSpy

static NSUInteger sInboxResetCalls = 0;
static void (^sInboxResetHook)(void) = nil;

+ (void)resetCounters { sInboxResetCalls = 0; }
+ (NSUInteger)resetApplicationCalls { return sInboxResetCalls; }
+ (void)setResetHook:(void (^)(void))hook { sInboxResetHook = [hook copy]; }

+ (void)resetApplication {
    sInboxResetCalls++;
    if (sInboxResetHook) {
        sInboxResetHook();
    }
}

+ (BOOL)isInboxPushNotification:(NSDictionary *)userInfo { return NO; }
+ (void)addInboxMessageFromPushNotification:(NSDictionary *)userInfo {}
+ (void)actionInboxMessageFromPushNotification:(NSDictionary *)userInfo {}
+ (void)updateInboxForNewUserId:(void (^)(NSUInteger))completion {}
+ (void)loadMessagesWithCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *, NSError *))completion {}
+ (void)readMessagesWithCodes:(NSArray<NSString *> *)codes {}
+ (void)deleteMessagesWithCodes:(NSArray<NSString *> *)codes {}
+ (void)performActionForMessageWithCode:(NSString *)code {}
+ (void)markAllMessagesAsRead {}
+ (void)deleteAllReadMessages {}

@end

@interface PWActiveApplicationTest : XCTestCase

@property (nonatomic) PWPreferences *settings;
@property (nonatomic, copy) NSString *savedAppId;
@property (nonatomic, copy) NSString *savedBaseUrl;
@property (nonatomic, copy) NSString *savedInfoPlistAppId;
@property (nonatomic, copy) NSDictionary *savedRecord;
@property (nonatomic, copy) NSString *savedInMemoryAppCode;

@property (nonatomic, strong) PWRequestManager *requestManager;
@property (nonatomic, strong) PWRetryQueue *savedRetryQueue;
@property (nonatomic, strong) PWRetryQueue *scopedRetryQueue;
@property (nonatomic, strong) SwitchScopedRetryTransport *retryTransport;
@property (nonatomic, strong) NSURL *retryFileURL;

@end

@implementation PWActiveApplicationTest

- (void)setUp {
    [super setUp];
    _settings = [PWPreferences preferences];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _savedAppId = [[defaults objectForKey:kAppIdKey] copy];
    _savedBaseUrl = [[defaults objectForKey:kBaseUrlKey] copy];
    _savedInfoPlistAppId = [[defaults objectForKey:kInfoPlistAppIdKey] copy];
    _savedRecord = [[defaults objectForKey:kRecordKey] copy];
    _savedInMemoryAppCode = [_settings.appCode copy];

    [defaults removeObjectForKey:kRecordKey];
    [defaults synchronize];
}

- (void)tearDown {
    [SwitchInboxSpy setResetHook:nil];
    [self uninstallScopedRetryQueue];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kRecordKey];
    [self restoreKey:kAppIdKey value:_savedAppId];
    [self restoreKey:kInfoPlistAppIdKey value:_savedInfoPlistAppId];
    [defaults synchronize];

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    [shared removeObjectForKey:kRecordKey];
    [shared removeObjectForKey:kEffectiveKey];
    [shared removeObjectForKey:kAppIdKey];
    [shared synchronize];

    _settings.appCode = _savedInMemoryAppCode;
    NSString *resolvedBaseUrl = _savedBaseUrl.length > 0 ? _savedBaseUrl : [_settings defaultBaseUrl];
    if (resolvedBaseUrl.length > 0) {
        [_settings updateBaseUrl:resolvedBaseUrl];
    }
    [self restoreKey:kBaseUrlKey value:_savedBaseUrl];

    if (_savedRecord) {
        [defaults setObject:_savedRecord forKey:kRecordKey];
    }
    [defaults synchronize];

    [super tearDown];
}

- (void)restoreKey:(NSString *)key value:(NSString *)value {
    if (value) {
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
}

#pragma mark - Retry queue driven through the public switch API

/// Swaps the shared request manager's retry queue for one with a fake transport, so a switch driven
/// through `PushwooshConfig` can be observed end to end. Restored in tearDown.
- (void)installScopedRetryQueueWithCurrentUrl:(NSString *)currentUrl {
    [[PWNetworkModule module] inject:self];

    _retryTransport = [SwitchScopedRetryTransport new];
    _retryTransport.currentUrl = currentUrl;

    PWRetryPolicy *policy = [PWRetryPolicy new];
    policy.baseDelay = 0.01;
    policy.minDelay = 0.01;
    policy.maxDelay = 0.05;
    policy.jitterFraction = 0;
    policy.maxAttempts = 1000;

    NSString *name = [NSString stringWithFormat:@"PWActiveApplicationTest-%@", [[NSUUID UUID] UUIDString]];
    _retryFileURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:name];
    PWRetryQueueStorage *storage = [[PWRetryQueueStorage alloc] initWithFileURL:_retryFileURL];

    _savedRetryQueue = _requestManager.retryQueue;
    _scopedRetryQueue = [[PWRetryQueue alloc] initWithTransport:_retryTransport policy:policy storage:storage];
    _requestManager.retryQueue = _scopedRetryQueue;
}

- (void)uninstallScopedRetryQueue {
    if (_scopedRetryQueue == nil) {
        return;
    }
    _requestManager.retryQueue = _savedRetryQueue;
    [_scopedRetryQueue purgeAllEntriesWithReason:@"test teardown"];
    [self drainRetryQueue];
    [[NSFileManager defaultManager] removeItemAtURL:_retryFileURL error:nil];
    _scopedRetryQueue = nil;
    _savedRetryQueue = nil;
    _retryTransport = nil;
}

- (void)drainRetryQueue {
    for (int i = 0; i < 6; i++) {
        dispatch_sync(_scopedRetryQueue.serialQueue, ^{});
    }
}

- (NSUInteger)queuedEntryCount {
    __block NSUInteger count = 0;
    dispatch_sync(_scopedRetryQueue.serialQueue, ^{ count = _scopedRetryQueue.entries.count; });
    return count;
}

- (void)enqueuePinnedStatEventForAppCode:(NSString *)appCode baseUrl:(NSString *)baseUrl {
    PWRequest *request = [SwitchScopedPayloadRequest new];
    request.pinnedAppCode = appCode;
    request.pinnedBaseUrl = baseUrl;
    [_scopedRetryQueue enqueueRequest:request baseUrl:baseUrl];
    [self drainRetryQueue];
}

/// Enqueues an entry shaped like the real unregister of the application being left: pinned to that
/// application and its host, and flagged to outlive the switch.
- (void)enqueueSurvivingUnregisterForAppCode:(NSString *)appCode baseUrl:(NSString *)baseUrl {
    PWRequest *request = [SwitchScopedUnregisterRequest new];
    request.pinnedAppCode = appCode;
    request.pinnedBaseUrl = baseUrl;
    request.survivesApplicationChange = YES;
    [_scopedRetryQueue enqueueRequest:request baseUrl:baseUrl];
    [self drainRetryQueue];
}

- (NSArray<NSString *> *)queuedMethodNames {
    __block NSArray *names = nil;
    dispatch_sync(_scopedRetryQueue.serialQueue, ^{
        names = [_scopedRetryQueue.entries valueForKey:@"methodName"];
    });
    return names;
}

- (BOOL)waitUntil:(BOOL (^)(void))condition {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!condition() && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return condition();
}

- (NSDictionary *)persistedRecord {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kRecordKey];
}

#pragma mark - Transaction

/// Verifies that a switch persists both halves of the pair as one dictionary and both getters agree.
- (void)testSwitchApplicationPersistsPairAtomically {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    NSDictionary *record = [self persistedRecord];
    XCTAssertEqualObjects(record[@"appCode"], kAppCodeB);
    XCTAssertEqualObjects(record[@"baseUrl"], kUrlB);
    XCTAssertNotNil(record[@"updatedAt"]);

    XCTAssertEqualObjects([_settings appCode], kAppCodeB);
    XCTAssertEqualObjects([_settings baseUrl], kUrlB);
}

/// Verifies that an invalid base URL is rejected and neither half of the previous pair is touched.
- (void)testSwitchApplicationRejectsInvalidUrlAndChangesNothing {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    XCTAssertFalse([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:@"ftp://region-b.example.com/"]);
    XCTAssertFalse([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:@"https://has space.example.com/"]);

    XCTAssertEqualObjects([self persistedRecord][@"appCode"], kAppCodeA);
    XCTAssertEqualObjects([self persistedRecord][@"baseUrl"], kUrlA);
    XCTAssertEqualObjects([_settings appCode], kAppCodeA);
    XCTAssertEqualObjects([_settings baseUrl], kUrlA);
}

/// Verifies that an empty application code is rejected and nothing is written.
- (void)testSwitchApplicationRejectsEmptyAppCode {
    XCTAssertFalse([_settings switchToApplicationWithAppCode:@"   " baseUrl:kUrlB]);
    XCTAssertNil([self persistedRecord]);
}

/// Verifies that a dotted application code is rejected at the transaction and nothing is written.
- (void)testSwitchApplicationRejectsDottedAppCode {
    XCTAssertFalse([_settings switchToApplicationWithAppCode:@"XXXXX-XXXXX.legacy" baseUrl:kUrlB]);
    XCTAssertNil([self persistedRecord]);
}

/// Verifies that a nil base URL records no URL and falls back to the default cascade.
- (void)testSwitchApplicationWithNilUrlFallsBackToDefault {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig requestUrl]).andReturn(nil);

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:nil]);

    XCTAssertNil([self persistedRecord][@"baseUrl"]);
    XCTAssertEqualObjects([_settings baseUrl], @"https://BBBBB-22222.api.pushwoosh.com/json/1.3/");

    [mockConfig stopMocking];
}

/// Verifies that an empty base URL is a malformed URL, not an absent one, and is rejected together with the whole call.
- (void)testSwitchApplicationRejectsAnEmptyUrl {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    XCTAssertFalse([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:@""]);

    XCTAssertEqualObjects([self persistedRecord][@"appCode"], kAppCodeA);
    XCTAssertEqualObjects([self persistedRecord][@"baseUrl"], kUrlA);
    XCTAssertEqualObjects([_settings appCode], kAppCodeA);
}

/// Verifies that the recorded base URL is normalized with a trailing slash.
- (void)testSwitchApplicationNormalizesTrailingSlash {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:@"https://region-b.example.com/json/1.3"]);

    XCTAssertEqualObjects([self persistedRecord][@"baseUrl"], @"https://region-b.example.com/json/1.3/");
    XCTAssertEqualObjects([_settings baseUrl], @"https://region-b.example.com/json/1.3/");
}

#pragma mark - Precedence

/// Verifies that a persisted record outranks the Info.plist application code and base URL on a fresh read — this is the "survives restart" case.
- (void)testRecordWinsOverInfoPlistOnFreshRead {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appId]).andReturn(kAppCodeA);
    OCMStub([mockConfig appIdDev]).andReturn(nil);
    OCMStub([mockConfig requestUrl]).andReturn(kUrlA);
    OCMStub([mockConfig appGroupsName]).andReturn(nil);

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kBaseUrlKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [_settings writeActiveApplicationRecordWithAppCode:kAppCodeB baseUrl:kUrlB];

    PWPreferences *fresh = [[PWPreferences alloc] init];

    XCTAssertEqualObjects([fresh appCode], kAppCodeB);
    XCTAssertEqualObjects([fresh baseUrl], kUrlB);

    [mockConfig stopMocking];
}

/// Verifies that +resetCache keeps Pushwoosh_BASEURL while a record exists and still deletes it without one.
- (void)testRecordSurvivesResetCache {
    [_settings writeActiveApplicationRecordWithAppCode:kAppCodeB baseUrl:kUrlB];
    [[NSUserDefaults standardUserDefaults] setObject:kUrlB forKey:kBaseUrlKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [PWPreferences resetCache];
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:kBaseUrlKey], kUrlB);

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRecordKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [PWPreferences resetCache];
    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:kBaseUrlKey]);
}

/// Verifies that a malformed record is treated as absent and is not silently repaired or deleted.
- (void)testMalformedRecordIsTreatedAsAbsent {
    NSArray *invalidRecords = @[
        @[@"not", @"a", @"dictionary"],
        @{ @"appCode": @"" },
        @{ @"appCode": @42 },
        @{ @"appCode": kAppCodeB, @"baseUrl": @42 },
        @{ @"appCode": kAppCodeB, @"baseUrl": @"" },
        @{ @"appCode": @"XXXXX-XXXXX.legacy", @"baseUrl": kUrlB },
        @{ @"appCode": kAppCodeB, @"baseUrl": @"https://region-b.example.com@evil.tld/json/1.3/" },
        @{ @"appCode": kAppCodeB, @"baseUrl": @"ftp://region-b.example.com/json/1.3/" }
    ];

    for (id invalid in invalidRecords) {
        [[NSUserDefaults standardUserDefaults] setObject:invalid forKey:kRecordKey];
        [[NSUserDefaults standardUserDefaults] synchronize];

        XCTAssertFalse([PWPreferences hasActiveApplicationRecord], @"Expected %@ to be treated as absent", invalid);
        XCTAssertNotNil([[NSUserDefaults standardUserDefaults] objectForKey:kRecordKey], @"A corrupt record must not be deleted");
    }
}

/// ADR-6: Verifies that a plain setAppCode: drops the endpoint selected for the previous application instead of addressing the new one to it.
- (void)testPlainSetAppCodeDropsTheSelectedEndpointAndFallsBackToTheDefault {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig requestUrl]).andReturn(nil);

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [_settings setAppCode:kAppCodeB];

    XCTAssertEqualObjects([self persistedRecord][@"appCode"], kAppCodeB);
    XCTAssertNil([self persistedRecord][@"baseUrl"], @"an endpoint chosen for another application must not be carried over");
    XCTAssertEqualObjects([_settings baseUrl], @"https://BBBBB-22222.api.pushwoosh.com/json/1.3/");

    [mockConfig stopMocking];
}

/// Verifies that a plain setAppCode: falls back to the Info.plist endpoint when there is one.
- (void)testPlainSetAppCodeFallsBackToTheInfoPlistEndpoint {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig requestUrl]).andReturn(@"https://plist.example.com/json/1.3/");

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [_settings setAppCode:kAppCodeB];

    XCTAssertEqualObjects([_settings baseUrl], @"https://plist.example.com/json/1.3/");

    [mockConfig stopMocking];
}

/// Provenance split: verifies that a server-driven URL moves only the effective endpoint and never becomes the integrator's recorded choice.
- (void)testUpdateBaseUrlMovesTheEffectiveUrlAndNeverWritesTheRecord {
    [_settings updateBaseUrl:@"https://no-record.example.com/json/1.3/"];
    XCTAssertNil([self persistedRecord], @"updateBaseUrl: must never create a record");

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [_settings updateBaseUrl:kRotatedUrlB];

    XCTAssertEqualObjects([self persistedRecord][@"appCode"], kAppCodeA);
    XCTAssertEqualObjects([self persistedRecord][@"baseUrl"], kUrlA, @"the integrator's recorded URL must be untouched");
    XCTAssertEqualObjects([_settings baseUrl], kRotatedUrlB, @"the effective endpoint must follow the rotation");
}

/// Verifies that clearing the effective endpoint falls back to the integrator's recorded URL, not to the Info.plist application.
- (void)testClearingTheEffectiveUrlFallsBackToTheRecordedUrl {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig requestUrl]).andReturn(@"https://plist.example.com/json/1.3/");

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    [_settings updateBaseUrl:kRotatedUrlB];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kBaseUrlKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    PWPreferences *fresh = [[PWPreferences alloc] init];

    XCTAssertEqualObjects([fresh baseUrl], kUrlA);

    [mockConfig stopMocking];
}

#pragma mark - Repeat calls (wrappers call the switch on every app start)

/// Verifies that repeating the integrator's own previous pair changes nothing observable — no record write, no switch notification, no registration reset.
- (void)testRepeatSwitchWithTheSamePairIsAFullNoOp {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);
    NSDictionary *recordAfterFirstSwitch = [[self persistedRecord] copy];
    _settings.lastRegTime = [NSDate date];

    __block NSInteger switchNotifications = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kPWActiveApplicationChangedNotification
                                                                   object:nil
                                                                    queue:nil
                                                               usingBlock:^(NSNotification *note) { switchNotifications++; }];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    XCTAssertEqual(switchNotifications, 0, @"a no-op switch must not notify, so the retry queue is not purged");
    XCTAssertEqualObjects([self persistedRecord], recordAfterFirstSwitch, @"a no-op switch must not rewrite the record");
    XCTAssertNotNil([_settings lastRegTime], @"a no-op switch must not drop the registration dedup");

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

/// Verifies that repeating the integrator's constant pair after a server rotation puts the selected endpoint back, in one call — the no-op verdict is taken against the effective URL, not against the record.
- (void)testRepeatedSwitchWithTheSamePairReassertsTheEndpointAfterAServerRotation {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);
    [_settings updateBaseUrl:kRotatedUrlB];
    XCTAssertEqualObjects([_settings baseUrl], kRotatedUrlB);

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    XCTAssertEqualObjects([_settings baseUrl], kUrlB);
    XCTAssertEqualObjects([self persistedRecord][@"baseUrl"], kUrlB);
}

/// Verifies that putting the endpoint back after a rotation is not treated as an application change: the inbox and the queued statistics of that application survive it.
- (void)testReassertingTheEndpointAfterARotationDoesNotAnnounceAnApplicationChange {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);
    [_settings updateBaseUrl:kRotatedUrlB];

    __block NSNumber *announcedAppCodeChanged = nil;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kPWActiveApplicationChangedNotification
                                                                    object:nil
                                                                     queue:nil
                                                                usingBlock:^(NSNotification *note) {
        announcedAppCodeChanged = note.userInfo[kPWActiveApplicationChangedAppCodeChangedKey];
    }];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    XCTAssertEqualObjects(announcedAppCodeChanged, @NO, @"the application code did not move, so nothing application-scoped may be reset");

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

/// Verifies that a repeat call with the same pair does not unregister the device from the application it is still using.
- (void)testRepeatSwitchWithTheSamePairDoesNotUnregister {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);
    OCMReject([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]);

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlB];

    OCMVerifyAll(mockBridge);
    [mockBridge stopMocking];
}

/// Verifies that a rejected switch does not unregister the device from the application it is still using.
- (void)testRejectedSwitchDoesNotUnregister {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);
    OCMReject([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]);

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:@"ftp://region-b.example.com/"];

    OCMVerifyAll(mockBridge);
    XCTAssertEqualObjects([_settings appCode], kAppCodeA);
    [mockBridge stopMocking];
}

#pragma mark - Registration side effects

/// Verifies that a URL-only switch clears the registration dedup so the new host learns about the device on the next activation rather than in 24 hours.
- (void)testUrlOnlySwitchClearsTheRegistrationDedup {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    _settings.lastRegTime = [NSDate date];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:@"https://region-a-moved.example.com/json/1.3/"]);

    XCTAssertNil([_settings lastRegTime]);
}

/// Verifies that an application change clears the registration dedup so the new application registers immediately.
- (void)testApplicationSwitchClearsTheRegistrationDedup {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    _settings.lastRegTime = [NSDate date];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    XCTAssertNil([_settings lastRegTime]);
}

/// Verifies that a server-side rotation of the effective URL leaves the integrator's selection alone.
- (void)testServerRotationDoesNotRewriteTheSelection {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [_settings updateBaseUrl:kRotatedUrlB];

    XCTAssertEqualObjects([_settings baseUrl], kRotatedUrlB);
    XCTAssertEqualObjects([self persistedRecord][@"baseUrl"], kUrlA, @"a rotation must not rewrite the selection");
}

/// Verifies that an application change registers the device in the new application through the app-code KVO path.
- (void)testApplicationSwitchRegistersThroughTheAppCodeKvoPath {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    PWPushNotificationsManager *manager = [PWPushNotificationsManager new];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    PWPushNotificationsManager *savedManager = [PWManagerBridge shared].pushNotificationManager;
    id mockManager = OCMPartialMock(manager);
    OCMStub([mockManager updateRegistration]).andDo(nil);
    [PWManagerBridge shared].pushNotificationManager = mockManager;

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlB];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];

    OCMVerify([mockManager updateRegistration]);

    [PWManagerBridge shared].pushNotificationManager = savedManager;
    [mockManager stopMocking];
}

/// Verifies a host move inside one application forces no registration at all: the application code did not change, so the KVO path stays silent and nothing else re-registers either. The dedup reset is what lets the next ordinary activation do it.
- (void)testUrlOnlySwitchForcesNoRegistration {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    PWPushNotificationsManager *manager = [PWPushNotificationsManager new];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    PWPushNotificationsManager *savedManager = [PWManagerBridge shared].pushNotificationManager;
    id mockManager = OCMPartialMock(manager);
    OCMStub([mockManager updateRegistration]).andDo(nil);
    OCMReject([mockManager updateRegistration]);
    [PWManagerBridge shared].pushNotificationManager = mockManager;

    [PushwooshConfig setAppCode:kAppCodeA baseUrl:@"https://region-a-moved.example.com/json/1.3/"];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    OCMVerifyAll(mockManager);

    [PWManagerBridge shared].pushNotificationManager = savedManager;
    [mockManager stopMocking];
}

/// FIX 29: Verifies a URL-only switch driven through the public API keeps the queued statistics and replays them to the new host.
- (void)testUrlOnlySwitchThroughPublicApiKeepsQueuedEventsAndReplaysThemToTheNewHost {
    NSString *movedUrl = @"https://region-a-moved.example.com/json/1.3/";
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [self installScopedRetryQueueWithCurrentUrl:kUrlA];
    [self enqueuePinnedStatEventForAppCode:kAppCodeA baseUrl:kUrlA];
    XCTAssertEqual([self queuedEntryCount], 1u);

    _retryTransport.currentUrl = movedUrl;
    [PushwooshConfig setAppCode:kAppCodeA baseUrl:movedUrl];
    [self drainRetryQueue];

    XCTAssertEqual([self queuedEntryCount], 1u, @"a host move inside one application must not purge its queued events");

    XCTAssertTrue([self waitUntil:^BOOL {
        return [[_retryTransport recordedBaseUrls] containsObject:movedUrl];
    }], @"the queued event must be replayed against the new host");
}

/// FIX 29: Verifies a switch to another application driven through the public API purges the queue.
- (void)testApplicationSwitchThroughPublicApiPurgesQueuedEvents {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [self installScopedRetryQueueWithCurrentUrl:kUrlA];
    [self enqueuePinnedStatEventForAppCode:kAppCodeA baseUrl:kUrlA];
    XCTAssertEqual([self queuedEntryCount], 1u);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    _retryTransport.currentUrl = kUrlB;
    [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlB];
    [self drainRetryQueue];

    XCTAssertEqual([self queuedEntryCount], 0u, @"events of the application being left must be dropped");

    [mockBridge stopMocking];
}

/// Verifies that a URL-only switch does not unregister the device — it is the same application.
- (void)testUrlOnlySwitchDoesNotUnregister {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);
    OCMReject([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]);

    [PushwooshConfig setAppCode:kAppCodeA baseUrl:@"https://region-a-moved.example.com/json/1.3/"];

    OCMVerifyAll(mockBridge);
    [mockBridge stopMocking];
}

/// ADR-7: Verifies that switching applications unregisters the device from the previous one, pinned to the previous pair.
- (void)testSwitchApplicationUnregistersPreviousApplicationWithPinnedPair {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlB];

    OCMVerify([mockBridge unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    XCTAssertEqualObjects([_settings appCode], kAppCodeB);
    XCTAssertEqualObjects([_settings baseUrl], kUrlB);

    [mockBridge stopMocking];
}

/// Verifies that a first-launch switch (no previous application code) sends no unregister.
- (void)testFirstLaunchSwitchDoesNotUnregister {
    _settings.appCode = nil;

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);
    OCMReject([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]);

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlB];

    OCMVerifyAll(mockBridge);
    [mockBridge stopMocking];
}

/// Verifies that the pinned unregister carries the previous application code, previous host and the user id current at call time, and keeps the local push token.
- (void)testPinnedUnregisterRequestCarriesPreviousPair {
    PWPushNotificationsManagerCommon *manager = [PWPushNotificationsManagerCommon new];

    NSString *savedUserId = [[PWPreferences preferences].userId copy];
    [PWPreferences preferences].userId = @"user-in-the-previous-application";

    id mockPrefs = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPrefs pushToken]).andReturn(@"abcdef0123456789");
    OCMStub([mockPrefs registrationEverOccured]).andReturn(YES);
    OCMReject([mockPrefs setPushToken:OCMOCK_ANY]);

    id mockRetry = OCMClassMock([PWSessionRetrySender class]);
    __block PWRequest *sent = nil;
    OCMStub([mockRetry sendWithRetry:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWRequest *request = nil;
        [invocation getArgument:&request atIndex:2];
        sent = request;
    });
    manager.sessionRetry = mockRetry;

    [manager unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA];

    OCMVerifyAll(mockPrefs);
    [mockPrefs stopMocking];
    [PWPreferences preferences].userId = @"user-set-after-the-switch";

    XCTAssertTrue([sent isKindOfClass:[PWUnregisterDeviceRequest class]]);
    XCTAssertEqualObjects([sent requestDictionary][@"application"], kAppCodeA);
    XCTAssertEqualObjects([sent baseUrl], kUrlA);
    XCTAssertEqualObjects([sent requestDictionary][@"userId"], @"user-in-the-previous-application",
                          @"the unregister must carry the user of the application being left");
    XCTAssertTrue(sent.cacheable, @"the unregister must reach the persistent queue if the session attempts fail");
    XCTAssertTrue(sent.survivesApplicationChange, @"and it must not be purged with the events of the application being left");

    [mockRetry stopMocking];
    if (savedUserId) {
        [PWPreferences preferences].userId = savedUserId;
    }
}

/// Verifies that with a reverse proxy configured the unregister is not pinned to the raw previous host — the proxy carries every request, so the URL resolves to it at send time.
- (void)testPinnedUnregisterFollowsReverseProxyWhenConfigured {
    PWPushNotificationsManagerCommon *manager = [PWPushNotificationsManagerCommon new];

    id mockPrefs = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPrefs pushToken]).andReturn(@"abcdef0123456789");
    OCMStub([mockPrefs registrationEverOccured]).andReturn(YES);

    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockRequestManager isUsingReverseProxy]).andReturn(YES);
    manager.requestManager = mockRequestManager;

    id mockRetry = OCMClassMock([PWSessionRetrySender class]);
    __block PWRequest *sent = nil;
    OCMStub([mockRetry sendWithRetry:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWRequest *request = nil;
        [invocation getArgument:&request atIndex:2];
        sent = request;
    });
    manager.sessionRetry = mockRetry;

    [manager unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA];

    XCTAssertTrue([sent isKindOfClass:[PWUnregisterDeviceRequest class]]);
    XCTAssertEqualObjects([sent requestDictionary][@"application"], kAppCodeA,
                          @"the body must still name the application being left");
    XCTAssertNil([sent baseUrl],
                 @"a pinned host would bypass the reverse proxy; unpinned resolves to the proxy at send time");

    [mockRetry stopMocking];
    [mockRequestManager stopMocking];
    [mockPrefs stopMocking];
}

/// Verifies that the unregister is skipped when the device has no push token — there is nothing to undo.
- (void)testPinnedUnregisterSkippedWithoutPushToken {
    PWPushNotificationsManagerCommon *manager = [PWPushNotificationsManagerCommon new];

    id mockPrefs = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPrefs pushToken]).andReturn(nil);
    OCMStub([mockPrefs registrationEverOccured]).andReturn(YES);

    id mockRetry = OCMClassMock([PWSessionRetrySender class]);
    OCMReject([mockRetry sendWithRetry:OCMOCK_ANY completion:OCMOCK_ANY]);
    manager.sessionRetry = mockRetry;

    [manager unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA];

    OCMVerifyAll(mockRetry);
    [mockRetry stopMocking];
    [mockPrefs stopMocking];
}

#pragma mark - Superseded pair (FIX 20)

/// Verifies the transaction reports the pair it actually superseded, so the unregister cannot be aimed at a stale pair read before the call.
- (void)testTransactionReportsTheSupersededPair {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    NSDictionary<NSString *, NSString *> *previousPair = nil;
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB previousPair:&previousPair]);

    XCTAssertEqualObjects(previousPair[@"appCode"], kAppCodeA);
    XCTAssertEqualObjects(previousPair[@"baseUrl"], kUrlA);
}

/// Verifies a no-op repeat supersedes nothing, so no unregister can be derived from it.
- (void)testNoOpSwitchReportsNoSupersededPair {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    NSDictionary<NSString *, NSString *> *previousPair = nil;
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB previousPair:&previousPair]);

    XCTAssertNil(previousPair);
}

/// Verifies a rejected switch supersedes nothing.
- (void)testRejectedSwitchReportsNoSupersededPair {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    NSDictionary<NSString *, NSString *> *previousPair = nil;
    XCTAssertFalse([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:@"ftp://nope.example.com/" previousPair:&previousPair]);

    XCTAssertNil(previousPair);
}

/// Verifies that overlapping switches unregister EVERY vacated application: the set of unregistered application codes plus the surviving one must cover every application that was ever selected.
- (void)testOverlappingSwitchesUnregisterEveryVacatedApplication {
    NSString *appC = @"CCCCC-33333";
    NSString *urlC = @"https://region-c.example.com/json/1.3/";

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    NSMutableArray<NSString *> *unregistered = [NSMutableArray array];
    NSObject *recordLock = [NSObject new];
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSString *code = nil;
        [invocation getArgument:&code atIndex:2];
        @synchronized (recordLock) {
            [unregistered addObject:code ?: @""];
        }
    });

    XCTestExpectation *first = [self expectationWithDescription:@"switch to B"];
    XCTestExpectation *second = [self expectationWithDescription:@"switch to C"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlB];
        [first fulfill];
    });
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [PushwooshConfig setAppCode:appC baseUrl:urlC];
        [second fulfill];
    });
    [self waitForExpectationsWithTimeout:20 handler:nil];

    NSMutableSet *covered = nil;
    @synchronized (recordLock) {
        covered = [NSMutableSet setWithArray:unregistered];
    }
    [covered addObject:[_settings appCode]];

    XCTAssertTrue([covered containsObject:kAppCodeA], @"the starting application was never unregistered");
    XCTAssertTrue([covered containsObject:kAppCodeB], @"application B was neither unregistered nor the survivor");
    XCTAssertTrue([covered containsObject:appC], @"application C was neither unregistered nor the survivor");

    [mockBridge stopMocking];
}

#pragma mark - App Group mirror / Notification Service Extension

/// FIX 21: Verifies a switch publishes the effective pair to the App Group exactly once, with the final application code AND the final endpoint — never a half-applied {old appCode, new baseUrl}.
- (void)testSwitchMirrorsTheEffectivePairOnceWithFinalValues {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(kTestSuiteName);

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockPrefs = OCMPartialMock(_settings);
    NSMutableArray<NSDictionary *> *mirrored = [NSMutableArray array];
    OCMStub([mockPrefs mirrorEffectiveApplicationIntoAppGroupWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSString *code = nil;
        __unsafe_unretained NSString *url = nil;
        [invocation getArgument:&code atIndex:2];
        [invocation getArgument:&url atIndex:3];
        NSMutableDictionary *entry = [NSMutableDictionary new];
        entry[@"appCode"] = code ?: @"";
        entry[@"baseUrl"] = url ?: @"";
        [mirrored addObject:entry];
    }).andForwardToRealObject();

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    XCTAssertEqual(mirrored.count, 1u, @"the switch must publish the pair once, not once per half");
    XCTAssertEqualObjects(mirrored.firstObject[@"appCode"], kAppCodeB);
    XCTAssertEqualObjects(mirrored.firstObject[@"baseUrl"], kUrlB);

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    XCTAssertEqualObjects([shared objectForKey:kEffectiveKey][@"appCode"], kAppCodeB);
    XCTAssertEqualObjects([shared objectForKey:kEffectiveKey][@"baseUrl"], kUrlB);

    [mockPrefs stopMocking];
    [mockConfig stopMocking];
}

/// Verifies updateBaseUrl: without an active-application record writes nothing into the App Group — legacy installs with an App Group configured for other purposes must not gain new keys.
- (void)testUpdateBaseUrlWithoutAnActiveApplicationRecordNeverMirrorsToAppGroup {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(kTestSuiteName);

    XCTAssertFalse([PWPreferences hasActiveApplicationRecord]);
    XCTAssertNotNil([_settings updateBaseUrl:kUrlC]);

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    XCTAssertNil([shared objectForKey:kEffectiveKey]);
    XCTAssertNil([shared objectForKey:kRecordKey]);

    [mockConfig stopMocking];
}

/// FIX 21: Verifies a server rotation outside a switch still reaches the extension — the mirror on the updateBaseUrl: path must not be suppressed in general.
- (void)testServerRotationOutsideASwitchStillMirrorsToTheAppGroup {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(kTestSuiteName);

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);
    [_settings updateBaseUrl:kRotatedUrlB];

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    XCTAssertEqualObjects([shared objectForKey:kEffectiveKey][@"appCode"], kAppCodeB);
    XCTAssertEqualObjects([shared objectForKey:kEffectiveKey][@"baseUrl"], kRotatedUrlB);

    [mockConfig stopMocking];
}


/// H8: Verifies that the record is mirrored into the App Group suite as one dictionary carrying both fields.
- (void)testSwitchApplicationMirrorsRecordIntoAppGroupSuite {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(kTestSuiteName);

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    NSDictionary *mirrored = [shared objectForKey:kRecordKey];
    XCTAssertEqualObjects(mirrored[@"appCode"], kAppCodeB);
    XCTAssertEqualObjects(mirrored[@"baseUrl"], kUrlB);

    [mockConfig stopMocking];
}

/// Verifies that the App Group carries the integrator's record and the effective pair as two separate dictionaries.
- (void)testAppGroupCarriesRecordAndEffectivePairSeparately {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(kTestSuiteName);

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);
    [_settings updateBaseUrl:kRotatedUrlB];

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    XCTAssertEqualObjects([shared objectForKey:kRecordKey][@"baseUrl"], kUrlB, @"the record keeps the integrator's choice");
    XCTAssertEqualObjects([shared objectForKey:kEffectiveKey][@"baseUrl"], kRotatedUrlB, @"the effective pair follows the rotation");
    XCTAssertEqualObjects([shared objectForKey:kEffectiveKey][@"appCode"], kAppCodeB);

    [mockConfig stopMocking];
}

/// Verifies the extension follows a legitimate server rotation: the effective pair outranks the integrator's record.
- (void)testLoadActiveApplicationFromAppGroupsPrefersTheEffectivePair {
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    [shared setObject:@{ @"appCode": kAppCodeB, @"baseUrl": kUrlB } forKey:kRecordKey];
    [shared setObject:@{ @"appCode": kAppCodeB, @"baseUrl": kRotatedUrlB } forKey:kEffectiveKey];
    [shared synchronize];

    PWPreferences *extensionSide = [[PWPreferences alloc] init];
    [extensionSide loadActiveApplicationFromAppGroups:kTestSuiteName];

    XCTAssertEqualObjects([extensionSide appCode], kAppCodeB);
    XCTAssertEqualObjects([extensionSide baseUrl], kRotatedUrlB);
}

/// Verifies that the extension-side reload applies the application the host app selected.
- (void)testLoadActiveApplicationFromAppGroupsAppliesHostSelection {
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    [shared setObject:@{ @"appCode": kAppCodeB, @"baseUrl": kUrlB } forKey:kRecordKey];
    [shared synchronize];

    PWPreferences *extensionSide = [[PWPreferences alloc] init];
    [extensionSide loadActiveApplicationFromAppGroups:kTestSuiteName];

    XCTAssertEqualObjects([extensionSide appCode], kAppCodeB);
    XCTAssertEqualObjects([extensionSide baseUrl], kUrlB);
}

/// Verifies the extension-side reload falls back to PWConfig.appGroupsName when no suite name is passed.
- (void)testLoadActiveApplicationFromAppGroupsFallsBackToConfiguredAppGroupsName {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(kTestSuiteName);

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    [shared setObject:@{ @"appCode": kAppCodeB, @"baseUrl": kUrlB } forKey:kRecordKey];
    [shared synchronize];

    PWPreferences *extensionSide = [[PWPreferences alloc] init];
    [extensionSide loadActiveApplicationFromAppGroups:nil];

    XCTAssertEqualObjects([extensionSide appCode], kAppCodeB);
    XCTAssertEqualObjects([extensionSide baseUrl], kUrlB);

    [mockConfig stopMocking];
}

/// A3: Verifies that a reused extension process follows a second switch — the reload is per push, not per process.
- (void)testLoadActiveApplicationFromAppGroupsFollowsSecondRecordOnSameInstance {
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    PWPreferences *extensionSide = [[PWPreferences alloc] init];

    [shared setObject:@{ @"appCode": kAppCodeA, @"baseUrl": kUrlA } forKey:kRecordKey];
    [shared synchronize];
    [extensionSide loadActiveApplicationFromAppGroups:kTestSuiteName];

    XCTAssertEqualObjects([extensionSide appCode], kAppCodeA);
    XCTAssertEqualObjects([extensionSide baseUrl], kUrlA);

    [shared setObject:@{ @"appCode": kAppCodeB, @"baseUrl": kUrlB } forKey:kRecordKey];
    [shared synchronize];
    [extensionSide loadActiveApplicationFromAppGroups:kTestSuiteName];

    XCTAssertEqualObjects([extensionSide appCode], kAppCodeB);
    XCTAssertEqualObjects([extensionSide baseUrl], kUrlB);
}

/// Verifies the extension-side reload never writes the App Group suite — the host app is the only writer of the record.
- (void)testLoadActiveApplicationFromAppGroupsNeverWritesTheSuite {
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    NSDictionary *seeded = @{ @"appCode": kAppCodeB, @"baseUrl": kUrlB };
    [shared setObject:seeded forKey:kRecordKey];
    [shared removeObjectForKey:kEffectiveKey];
    [shared removeObjectForKey:kAppIdKey];
    [shared synchronize];

    PWPreferences *extensionSide = [[PWPreferences alloc] init];
    [extensionSide loadActiveApplicationFromAppGroups:kTestSuiteName];

    NSUserDefaults *reread = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    XCTAssertEqualObjects([reread objectForKey:kRecordKey], seeded, @"the extension must not rewrite the record");
    XCTAssertNil([reread objectForKey:kEffectiveKey], @"the extension must not write the effective pair");
    XCTAssertNil([reread objectForKey:kAppIdKey], @"the extension must not mirror the application code back into the suite");
}

/// Verifies the extension-side reload applies both halves of the pair as one unit, so a request pinned in between can never see a torn pair.
- (void)testLoadActiveApplicationFromAppGroupsAppliesPairAtomically {
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:kTestSuiteName];
    [shared setObject:@{ @"appCode": kAppCodeA, @"baseUrl": kUrlA } forKey:kRecordKey];
    [shared synchronize];

    PWPreferences *extensionSide = [[PWPreferences alloc] init];
    [extensionSide loadActiveApplicationFromAppGroups:kTestSuiteName];

    NSDictionary *pairA = @{ @"appCode": kAppCodeA, @"baseUrl": kUrlA };
    NSDictionary *pairB = @{ @"appCode": kAppCodeB, @"baseUrl": kUrlB };
    XCTAssertEqualObjects([extensionSide activeApplicationSnapshot], pairA);

    [shared setObject:pairB forKey:kRecordKey];
    [shared synchronize];

    XCTestExpectation *finished = [self expectationWithDescription:@"reloads finished"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        for (NSInteger i = 0; i < 50; i++) {
            [extensionSide loadActiveApplicationFromAppGroups:kTestSuiteName];
        }
        [finished fulfill];
    });

    for (NSInteger i = 0; i < 200; i++) {
        NSDictionary *snapshot = [extensionSide activeApplicationSnapshot];
        XCTAssertTrue([snapshot isEqualToDictionary:pairA] || [snapshot isEqualToDictionary:pairB],
                      @"Observed a torn pair on the extension path: %@", snapshot);
    }

    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssertEqualObjects([extensionSide activeApplicationSnapshot], pairB);
}

#pragma mark - Thread safety

/// Verifies that a snapshot taken while switches run on another thread is always one whole pair, never a mix.
- (void)testActiveApplicationSnapshotIsConsistentDuringConcurrentSwitch {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    XCTestExpectation *finished = [self expectationWithDescription:@"switches finished"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        for (NSInteger i = 0; i < 20; i++) {
            if (i % 2 == 0) {
                [self.settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB];
            } else {
                [self.settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA];
            }
        }
        [finished fulfill];
    });

    NSDictionary *pairA = @{ @"appCode": kAppCodeA, @"baseUrl": kUrlA };
    NSDictionary *pairB = @{ @"appCode": kAppCodeB, @"baseUrl": kUrlB };

    for (NSInteger i = 0; i < 200; i++) {
        NSDictionary *snapshot = [_settings activeApplicationSnapshot];
        XCTAssertTrue([snapshot isEqualToDictionary:pairA] || [snapshot isEqualToDictionary:pairB],
                      @"Observed a torn pair: %@", snapshot);
    }

    [self waitForExpectationsWithTimeout:10 handler:nil];
}


#pragma mark - Switch matrix: application only, endpoint only, both

/// Verifies that changing only the application code keeps the endpoint that was selected for it.
- (void)testAppCodeOnlySwitchKeepsTheEndpoint {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlA]);

    XCTAssertEqualObjects([self persistedRecord][@"appCode"], kAppCodeB);
    XCTAssertEqualObjects([self persistedRecord][@"baseUrl"], kUrlA);
    XCTAssertEqualObjects([_settings appCode], kAppCodeB);
    XCTAssertEqualObjects([_settings baseUrl], kUrlA);
}

/// Verifies that an application-only switch unregisters from the previous application on the host both share.
- (void)testAppCodeOnlySwitchUnregistersOnTheSharedHost {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlA];

    OCMVerify([mockBridge unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    [mockBridge stopMocking];
}

/// Verifies that an application-only switch still purges the queued events of the application being left.
- (void)testAppCodeOnlySwitchPurgesQueuedEvents {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [self installScopedRetryQueueWithCurrentUrl:kUrlA];
    [self enqueuePinnedStatEventForAppCode:kAppCodeA baseUrl:kUrlA];
    XCTAssertEqual([self queuedEntryCount], 1u);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlA];
    [self drainRetryQueue];

    XCTAssertEqual([self queuedEntryCount], 0u, @"the application changed, so its queued events must not reach the new one");
    [mockBridge stopMocking];
}

/// SDK-882: Verifies the one-argument setAppCode: also unregisters the device from the application it leaves, on the previous host.
- (void)testPlainSetAppCodeUnregistersFromThePreviousApplication {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    [PushwooshConfig setAppCode:kAppCodeB];

    OCMVerify([mockBridge unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    XCTAssertEqualObjects([_settings appCode], kAppCodeB);
    [mockBridge stopMocking];
}

/// Verifies the one-argument setter isolates the queue exactly like the two-argument one: entries built
/// for the application it leaves are purged, not replayed into the new one.
- (void)testPlainSetAppCodePurgesQueuedEventsOfTheApplicationItLeaves {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [self installScopedRetryQueueWithCurrentUrl:kUrlA];
    [self enqueuePinnedStatEventForAppCode:kAppCodeA baseUrl:kUrlA];
    XCTAssertEqual([self queuedEntryCount], 1u);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    [PushwooshConfig setAppCode:kAppCodeB];
    [self drainRetryQueue];

    XCTAssertEqual([self queuedEntryCount], 0u, @"a plain setAppCode: that moves the application must purge its queued events");
    [mockBridge stopMocking];
}

/// Verifies the same setter handed the code already in use touches nothing: no purge, because no
/// application was left.
- (void)testPlainSetAppCodeWithTheSameCodeKeepsQueuedEvents {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [self installScopedRetryQueueWithCurrentUrl:kUrlA];
    [self enqueuePinnedStatEventForAppCode:kAppCodeA baseUrl:kUrlA];
    XCTAssertEqual([self queuedEntryCount], 1u);

    [PushwooshConfig setAppCode:kAppCodeA];
    [self drainRetryQueue];

    XCTAssertEqual([self queuedEntryCount], 1u, @"re-applying the selected application code must not drop its own queued events");
}

/// SDK-882: Verifies re-applying the same application code through the one-argument setter unregisters nothing.
- (void)testPlainSetAppCodeWithTheSameCodeDoesNotUnregister {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMReject([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]);

    [PushwooshConfig setAppCode:kAppCodeA];

    XCTAssertEqualObjects([_settings appCode], kAppCodeA);
    [mockBridge stopMocking];
}

/// SDK-882: Verifies the one-argument setter keeps the selected endpoint when it is handed the application code that is already selected.
- (void)testPlainSetAppCodeWithTheSameCodeKeepsTheSelectedEndpoint {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [PushwooshConfig setAppCode:kAppCodeA];

    XCTAssertEqualObjects([self persistedRecord][@"appCode"], kAppCodeA);
    XCTAssertEqualObjects([self persistedRecord][@"baseUrl"], kUrlA);
    XCTAssertEqualObjects([_settings baseUrl], kUrlA);
}

/// SDK-882: Verifies a full switch still unregisters exactly once — the transaction reports the vacated pair, the setter inside it must not report it again.
- (void)testSwitchUnregistersExactlyOnce {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlB];

    OCMVerify(times(1), [mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]);
    [mockBridge stopMocking];
}

/// Verifies that switching away and back unregisters from every application that was left.
- (void)testSwitchingBackAndForthUnregistersFromEachVacatedApplication {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlB];
    [PushwooshConfig setAppCode:kAppCodeA baseUrl:kUrlA];

    OCMVerify([mockBridge unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    OCMVerify([mockBridge unregisterFromApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);
    XCTAssertEqualObjects([_settings appCode], kAppCodeA);
    [mockBridge stopMocking];
}

/// Verifies a nil base URL is "no URL supplied", not "select the default": it behaves like the one-argument setter and leaves an endpoint chosen earlier alone. This is what keeps a binding that forwards an absent optional from destroying the selection.
- (void)testNilBaseUrlBehavesLikeTheOneArgumentSetterAndKeepsTheSelectedEndpoint {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);
    OCMReject([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]);

    [PushwooshConfig setAppCode:kAppCodeA baseUrl:nil];

    OCMVerifyAll(mockBridge);
    XCTAssertEqualObjects([self persistedRecord][@"baseUrl"], kUrlA);
    XCTAssertEqualObjects([_settings baseUrl], kUrlA);
    [mockBridge stopMocking];
}

/// Verifies a nil base URL with a different application code still changes the application, exactly like the one-argument setter: the endpoint chosen for the previous application is dropped and the default takes over.
- (void)testNilBaseUrlWithAnotherAppCodeStillChangesTheApplication {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig requestUrl]).andReturn(nil);

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:nil];

    OCMVerify([mockBridge unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    XCTAssertEqualObjects([_settings appCode], kAppCodeB);
    XCTAssertNil([self persistedRecord][@"baseUrl"]);
    XCTAssertEqualObjects([_settings baseUrl], @"https://BBBBB-22222.api.pushwoosh.com/json/1.3/");
    [mockBridge stopMocking];
    [mockConfig stopMocking];
}

/// Verifies a nil application code with a nil URL is rejected rather than delegated: the legacy setter reads a nil code as "clear the application code".
- (void)testNilAppCodeWithNilBaseUrlChangesNothing {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    NSString *missingCode = nil;
    [PushwooshConfig setAppCode:missingCode baseUrl:nil];

    XCTAssertEqualObjects([_settings appCode], kAppCodeA);
    XCTAssertEqualObjects([_settings baseUrl], kUrlA);
}

/// Verifies an empty base URL is read as "no URL supplied" like nil: with the selected code it behaves like the one-argument setter and leaves the endpoint alone.
- (void)testEmptyBaseUrlBehavesLikeTheOneArgumentSetterAndKeepsTheSelectedEndpoint {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);
    OCMReject([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]);

    [PushwooshConfig setAppCode:kAppCodeA baseUrl:@""];

    OCMVerifyAll(mockBridge);
    XCTAssertEqualObjects([_settings appCode], kAppCodeA);
    XCTAssertEqualObjects([self persistedRecord][@"baseUrl"], kUrlA);
    XCTAssertEqualObjects([_settings baseUrl], kUrlA);
    [mockBridge stopMocking];
}

/// Verifies an empty base URL with another application code changes the application exactly like the one-argument setter: the previous endpoint is dropped and the device is unregistered from the application it leaves.
- (void)testEmptyBaseUrlWithAnotherAppCodeStillChangesTheApplication {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig requestUrl]).andReturn(nil);

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:@""];

    OCMVerify([mockBridge unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    XCTAssertEqualObjects([_settings appCode], kAppCodeB);
    XCTAssertNil([self persistedRecord][@"baseUrl"]);
    XCTAssertEqualObjects([_settings baseUrl], @"https://BBBBB-22222.api.pushwoosh.com/json/1.3/");
    [mockBridge stopMocking];
    [mockConfig stopMocking];
}

/// Verifies a whitespace-only base URL is read as "no URL supplied" too, so a binding that pads an absent argument cannot reject the call.
- (void)testWhitespaceOnlyBaseUrlBehavesLikeTheOneArgumentSetter {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [PushwooshConfig setAppCode:kAppCodeA baseUrl:@"   "];

    XCTAssertEqualObjects([_settings appCode], kAppCodeA);
    XCTAssertEqualObjects([self persistedRecord][@"baseUrl"], kUrlA);
    XCTAssertEqualObjects([_settings baseUrl], kUrlA);
}

/// Verifies a whitespace-only base URL with another application code still changes the application, the only case where reading it as absent differs observably from rejecting it as malformed.
- (void)testWhitespaceOnlyBaseUrlWithAnotherAppCodeStillChangesTheApplication {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig requestUrl]).andReturn(nil);

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    [PushwooshConfig setAppCode:kAppCodeB baseUrl:@"   "];

    OCMVerify([mockBridge unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    XCTAssertEqualObjects([_settings appCode], kAppCodeB);
    XCTAssertNil([self persistedRecord][@"baseUrl"]);
    XCTAssertEqualObjects([_settings baseUrl], @"https://BBBBB-22222.api.pushwoosh.com/json/1.3/");
    [mockBridge stopMocking];
    [mockConfig stopMocking];
}

#pragma mark - Inbox isolation

/// Verifies that an application change resets the inbox, since inbox messages belong to one application.
- (void)testApplicationSwitchResetsTheInbox {
    Class savedBridge = [PWManagerBridge shared].inboxBridge;
    [PWManagerBridge shared].inboxBridge = [SwitchInboxSpy class];
    [SwitchInboxSpy resetCounters];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    [SwitchInboxSpy resetCounters];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    XCTAssertEqual([SwitchInboxSpy resetApplicationCalls], 1u);
    [PWManagerBridge shared].inboxBridge = savedBridge;
}

/// Verifies that the inbox reset of an application change runs OUTSIDE the switch lock: the real reset
/// archives two files synchronously, and a thread that only wants to read the active pair must not wait
/// for that.
- (void)testApplicationSwitchResetsTheInboxOutsideTheSwitchLock {
    Class savedBridge = [PWManagerBridge shared].inboxBridge;
    [PWManagerBridge shared].inboxBridge = [SwitchInboxSpy class];
    [SwitchInboxSpy resetCounters];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    [SwitchInboxSpy resetCounters];

    PWPreferences *settings = _settings;
    __block BOOL pairReadable = NO;
    [SwitchInboxSpy setResetHook:^{
        pairReadable = [self canReadActiveApplicationPairFromAnotherThread:settings];
    }];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    XCTAssertEqual([SwitchInboxSpy resetApplicationCalls], 1u);
    XCTAssertTrue(pairReadable, @"activeApplicationSnapshot blocked during the inbox reset, so the reset still runs under switchLock");

    [SwitchInboxSpy setResetHook:nil];
    [PWManagerBridge shared].inboxBridge = savedBridge;
}

/// Verifies that the `appCode` KVO notification of a switch still fires and fires OUTSIDE the switch
/// lock: the transaction applies the code without the setter, so it owes the notification, and every
/// observer of that key path is code the SDK does not own.
- (void)testApplicationSwitchAnnouncesTheAppCodeOutsideTheSwitchLock {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    PWPreferences *settings = _settings;
    SwitchAppCodeObserver *observer = [SwitchAppCodeObserver new];
    __block BOOL pairReadable = NO;
    __block NSString *observedAppCode = nil;
    observer.onChange = ^{
        observedAppCode = [settings appCode];
        pairReadable = [self canReadActiveApplicationPairFromAnotherThread:settings];
    };

    [_settings addObserver:observer forKeyPath:@"appCode" options:NSKeyValueObservingOptionNew context:nil];
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);
    [_settings removeObserver:observer forKeyPath:@"appCode"];

    XCTAssertEqual(observer.changeCount, 1u, @"the switch must announce the app code exactly once");
    XCTAssertEqualObjects(observedAppCode, kAppCodeB, @"an observer must see the committed application code");
    XCTAssertTrue(pairReadable, @"activeApplicationSnapshot blocked inside the appCode observer, so the notification still fires under switchLock");
}

/// YES when another thread can take the active-application snapshot right now, i.e. `switchLock` is free.
/// Used to prove that a callout the SDK hands to foreign code is not holding it.
- (BOOL)canReadActiveApplicationPairFromAnotherThread:(PWPreferences *)settings {
    dispatch_semaphore_t read = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [settings activeApplicationSnapshot];
        dispatch_semaphore_signal(read);
    });
    return dispatch_semaphore_wait(read, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC))) == 0;
}

/// Verifies that a host move keeps the inbox: the application did not change, so its messages are still valid.
- (void)testUrlOnlySwitchKeepsTheInbox {
    Class savedBridge = [PWManagerBridge shared].inboxBridge;
    [PWManagerBridge shared].inboxBridge = [SwitchInboxSpy class];
    [SwitchInboxSpy resetCounters];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    [SwitchInboxSpy resetCounters];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kRotatedUrlB]);

    XCTAssertEqual([SwitchInboxSpy resetApplicationCalls], 0u);
    [PWManagerBridge shared].inboxBridge = savedBridge;
}

#pragma mark - User registration dedup

/// Verifies that an application change clears the user registration dedup so the user is registered in the new application.
- (void)testApplicationSwitchClearsTheUserRegistrationDedup {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    _settings.lastRegisterUserDate = [NSDate date];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    XCTAssertNil([_settings lastRegisterUserDate]);
}

/// Verifies that a host move clears the user registration dedup too, so the user is re-declared on the new host at the next activation.
- (void)testUrlOnlySwitchClearsTheUserRegistrationDedup {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    _settings.lastRegisterUserDate = [NSDate date];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kRotatedUrlB]);

    XCTAssertNil([_settings lastRegisterUserDate]);
}

#pragma mark - Change notification

/// Verifies that an application change is announced with the app-code-changed flag set, which is what isolates per-application data.
- (void)testApplicationSwitchAnnouncesThatTheAppCodeChanged {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    __block NSNumber *flag = nil;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kPWActiveApplicationChangedNotification
                                                                    object:nil
                                                                     queue:nil
                                                                usingBlock:^(NSNotification *note) {
        flag = note.userInfo[kPWActiveApplicationChangedAppCodeChangedKey];
    }];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:kUrlB]);

    XCTAssertEqualObjects(flag, @YES);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

/// Verifies that a host move is announced with the flag clear, so observers keep the data of the unchanged application.
- (void)testUrlOnlySwitchAnnouncesThatTheAppCodeDidNotChange {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    __block NSNumber *flag = nil;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kPWActiveApplicationChangedNotification
                                                                    object:nil
                                                                     queue:nil
                                                                usingBlock:^(NSNotification *note) {
        flag = note.userInfo[kPWActiveApplicationChangedAppCodeChangedKey];
    }];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kRotatedUrlB]);

    XCTAssertEqualObjects(flag, @NO);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

/// Verifies that repeating the selected pair announces nothing, so wrappers calling it every launch cost nothing.
- (void)testNoOpSwitchAnnouncesNothing {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    __block NSUInteger notifications = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kPWActiveApplicationChangedNotification
                                                                    object:nil
                                                                     queue:nil
                                                                usingBlock:^(NSNotification *note) {
        notifications++;
    }];

    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    XCTAssertEqual(notifications, 0u);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

/// Verifies that a rejected switch announces nothing, since nothing changed.
- (void)testRejectedSwitchAnnouncesNothing {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    __block NSUInteger notifications = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kPWActiveApplicationChangedNotification
                                                                    object:nil
                                                                     queue:nil
                                                                usingBlock:^(NSNotification *note) {
        notifications++;
    }];

    XCTAssertFalse([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:@"ftp://region-b.example.com/"]);

    XCTAssertEqual(notifications, 0u);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

#pragma mark - Input handling

/// Verifies that a URL carrying userinfo is rejected, so a spoofed host cannot be selected.
- (void)testSwitchApplicationRejectsUrlCarryingUserinfo {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    XCTAssertFalse([_settings switchToApplicationWithAppCode:kAppCodeB baseUrl:@"https://region-b.example.com@evil.tld/json/1.3/"]);

    XCTAssertEqualObjects([_settings appCode], kAppCodeA);
    XCTAssertEqualObjects([_settings baseUrl], kUrlA);
}

/// Verifies that whitespace around the application code is trimmed rather than rejected or stored.
- (void)testSwitchApplicationTrimsWhitespaceAroundTheAppCode {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:@"  BBBBB-22222  " baseUrl:kUrlB]);

    XCTAssertEqualObjects([self persistedRecord][@"appCode"], kAppCodeB);
    XCTAssertEqualObjects([_settings appCode], kAppCodeB);
}

#pragma mark - Unregister gates

/// Verifies that the unregister is skipped when the device never registered, since there is nothing to undo.
- (void)testPinnedUnregisterSkippedWithoutPriorRegistration {
    PWPushNotificationsManagerCommon *manager = [PWPushNotificationsManagerCommon new];

    id mockPrefs = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPrefs pushToken]).andReturn(@"abcdef0123456789");
    OCMStub([mockPrefs registrationEverOccured]).andReturn(NO);

    id mockRetry = OCMClassMock([PWSessionRetrySender class]);
    OCMReject([mockRetry sendWithRetry:OCMOCK_ANY completion:OCMOCK_ANY]);
    manager.sessionRetry = mockRetry;

    [manager unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA];

    OCMVerifyAll(mockRetry);
    [mockRetry stopMocking];
    [mockPrefs stopMocking];
}


#pragma mark - The unregister must never be lost

/// Verifies that a queued unregister left over from an earlier switch survives the purge that drops the vacated application's events.
- (void)testQueuedUnregisterSurvivesTheApplicationSwitchPurge {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [self installScopedRetryQueueWithCurrentUrl:kUrlA];
    [self enqueuePinnedStatEventForAppCode:kAppCodeA baseUrl:kUrlA];
    [self enqueueSurvivingUnregisterForAppCode:kAppCodeC baseUrl:kUrlC];
    XCTAssertEqual([self queuedEntryCount], 2u);

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    _retryTransport.currentUrl = kUrlB;
    [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlB];
    [self drainRetryQueue];

    XCTAssertEqual([self queuedEntryCount], 1u, @"the statistics event goes, the unregister stays");
    XCTAssertEqualObjects([self queuedMethodNames], (@[@"unregisterDevice"]));
    [mockBridge stopMocking];
}

/// Verifies that the surviving unregister is replayed against the host of the application it names, not the new one.
- (void)testQueuedUnregisterIsReplayedAgainstThePreviousHost {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);

    [self installScopedRetryQueueWithCurrentUrl:kUrlA];

    id mockBridge = OCMPartialMock([PWManagerBridge shared]);
    OCMStub([mockBridge unregisterFromApplicationWithAppCode:OCMOCK_ANY baseUrl:OCMOCK_ANY]).andDo(nil);

    _retryTransport.currentUrl = kUrlB;
    [PushwooshConfig setAppCode:kAppCodeB baseUrl:kUrlB];

    [self enqueueSurvivingUnregisterForAppCode:kAppCodeA baseUrl:kUrlA];
    [self drainRetryQueue];

    XCTAssertTrue([self waitUntil:^BOOL {
        return [[_retryTransport recordedBaseUrls] containsObject:kUrlA];
    }], @"the unregister must be sent to the host of the application being left");
    XCTAssertFalse([[_retryTransport recordedBaseUrls] containsObject:kUrlB],
                   @"and never to the host of the new application");
    [mockBridge stopMocking];
}

/// Verifies that the survivor flag is preserved across the queue's archive, so a relaunch still delivers the unregister.
- (void)testSurvivingUnregisterSurvivesArchiving {
    PWRequest *request = [SwitchScopedPayloadRequest new];
    request.pinnedAppCode = kAppCodeA;
    request.pinnedBaseUrl = kUrlA;
    request.survivesApplicationChange = YES;

    PWRetryEntry *entry = [[PWRetryEntry alloc] initWithRequest:request baseUrl:kUrlA now:[NSDate date]];
    XCTAssertTrue(entry.survivesApplicationChange);

    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:entry requiringSecureCoding:YES error:nil];
    PWRetryEntry *restored = [NSKeyedUnarchiver unarchivedObjectOfClass:[PWRetryEntry class] fromData:archived error:nil];

    XCTAssertTrue(restored.survivesApplicationChange);
    XCTAssertEqualObjects(restored.baseUrl, kUrlA);
    XCTAssertEqual(entry.survivesApplicationChange, [entry entryByIncrementingAttemptWithNextDate:[NSDate date]].survivesApplicationChange);
}


/// Verifies that when the in-session attempts are exhausted the unregister is handed to the persistent queue rather than dropped.
- (void)testExhaustedUnregisterIsPersistedForLaterRetry {
    XCTAssertTrue([_settings switchToApplicationWithAppCode:kAppCodeA baseUrl:kUrlA]);
    [self installScopedRetryQueueWithCurrentUrl:kUrlA];

    PWPushNotificationsManagerCommon *manager = [PWPushNotificationsManagerCommon new];

    id mockPrefs = OCMPartialMock([PWPreferences preferences]);
    OCMStub([mockPrefs pushToken]).andReturn(@"abcdef0123456789");
    OCMStub([mockPrefs registrationEverOccured]).andReturn(YES);
    /// The device has already moved on (the unregister is persisted after the switch committed);
    /// with the frozen code still current the queue would rightly drop the entry as a returned switch.
    OCMStub([mockPrefs appCode]).andReturn(kAppCodeB);

    /// Stands in for a dead host: every session attempt fails with a transient error, so the sender
    /// runs out of attempts and has to persist the request.
    id mockRetry = OCMClassMock([PWSessionRetrySender class]);
    OCMStub([mockRetry sendWithRetry:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWRequest *request = nil;
        [invocation getArgument:&request atIndex:2];
        [_requestManager persistRequestForLaterRetry:request];
    });
    manager.sessionRetry = mockRetry;

    [manager unregisterFromApplicationWithAppCode:kAppCodeA baseUrl:kUrlA];
    [self drainRetryQueue];

    XCTAssertEqual([self queuedEntryCount], 1u, @"the unregister must be queued for a later launch");
    XCTAssertEqualObjects([self queuedMethodNames], (@[@"unregisterDevice"]));

    [mockRetry stopMocking];
    [mockPrefs stopMocking];
}

@end
