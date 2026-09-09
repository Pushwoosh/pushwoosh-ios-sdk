#import <XCTest/XCTest.h>

#import "PWInAppStorage.h"
#import "PWResource.h"
#import "PWNetworkModule.h"
#import "PWRequestManagerMock.h"

static NSString *const KeyInAppSavedResources = @"InAppSavedResources";

@interface PWInAppStorage (Test)

@property (atomic, strong) NSDictionary *resources;
@property (atomic, assign) volatile BOOL isUpdating;
@property (atomic, assign) volatile BOOL isSyncing;

@end

@interface PWInAppStorageTest : XCTestCase

@property (nonatomic, strong) PWRequestManagerMock *mockRequestManager;
@property (nonatomic, strong) PWRequestManager *originalRequestManager;

@end

@implementation PWInAppStorageTest

+ (void)clearDefaults {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyInAppSavedResources];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setUp {
    [super setUp];
    [self.class clearDefaults];
    [PWInAppStorage destroy];

    self.originalRequestManager = [PWNetworkModule module].requestManager;
    self.mockRequestManager = [PWRequestManagerMock new];
    [PWNetworkModule module].requestManager = self.mockRequestManager;
}

- (void)tearDown {
    [PWNetworkModule module].requestManager = self.originalRequestManager;
    [self removeLocalDataForCodes:@[@"sync-1", @"sync-2"]];
    [PWInAppStorage destroy];
    [self.class clearDefaults];
    [super tearDown];
}

#pragma mark - Singleton

/// Verifies that storage returns the same instance across calls.
- (void)testStorage_isSingleton {
    PWInAppStorage *a = [PWInAppStorage storage];
    PWInAppStorage *b = [PWInAppStorage storage];

    XCTAssertNotNil(a);
    XCTAssertEqual(a, b);
}

#pragma mark - Empty / corrupted persisted state

/// Verifies that a brand-new install (no persisted defaults) yields an empty resources dictionary without crashing.
- (void)testInit_noPersistedData_yieldsEmptyResources {
    PWInAppStorage *storage = [PWInAppStorage new];

    XCTAssertNotNil(storage.resources);
    XCTAssertEqual(storage.resources.count, 0u);
}

/// Verifies that a zero-length blob (interrupted prior save) yields an empty resources dictionary rather than crashing the unarchiver with "data parameter is nil".
- (void)testInit_zeroLengthPersistedData_yieldsEmptyResourcesWithoutCrash {
    [[NSUserDefaults standardUserDefaults] setObject:[NSData data] forKey:KeyInAppSavedResources];
    [[NSUserDefaults standardUserDefaults] synchronize];

    PWInAppStorage *storage = [PWInAppStorage new];

    XCTAssertNotNil(storage.resources);
    XCTAssertEqual(storage.resources.count, 0u);
}

/// Verifies that corrupted (non-archive) bytes yield an empty resources dictionary without crashing — unarchiver error path is handled, not propagated.
- (void)testInit_corruptedPersistedData_yieldsEmptyResourcesWithoutCrash {
    NSData *garbage = [@"not an archive" dataUsingEncoding:NSUTF8StringEncoding];
    [[NSUserDefaults standardUserDefaults] setObject:garbage forKey:KeyInAppSavedResources];
    [[NSUserDefaults standardUserDefaults] synchronize];

    PWInAppStorage *storage = [PWInAppStorage new];

    XCTAssertNotNil(storage.resources);
    XCTAssertEqual(storage.resources.count, 0u);
}

#pragma mark - Persistence round-trip

/// Verifies that a PWResource saved via resourceForDictionary: by one storage instance is loaded by a fresh instance reading from the same NSUserDefaults key. Exercises the PWResource + NSMutableDictionary + NSString entries of the SDK-826 secure-decode allowlist. Nested collection types are NOT covered here (PWResource.encodeWithCoder does not serialize tags) — see testPersistence_nestedCollectionTypesSurviveSecureDecodeAllowlist.
- (void)testPersistence_resourceWithTagsContainingArrayAndNullRoundTrips {
    PWInAppStorage *storage = [PWInAppStorage new];

    NSDictionary *resourceDict = @{
        @"code": @"inapp-1",
        @"url": @"https://example.com/inapp.zip",
        @"updated": @(1700000000),
        @"presentationStyleKey": @"fullscreen",
        @"closeButtonType": @(1),
        @"tags": @{
            @"locArgs": @[@"Anna", @"Bob"],
            @"badge": @42,
            @"optional": [NSNull null],
        },
    };
    PWResource *saved = [storage resourceForDictionary:resourceDict];
    XCTAssertNotNil(saved);
    XCTAssertEqualObjects(saved.code, @"inapp-1");

    PWInAppStorage *freshStorage = [PWInAppStorage new];

    XCTAssertEqual(freshStorage.resources.count, 1u);
    PWResource *loaded = [freshStorage resourceForCode:@"inapp-1"];
    XCTAssertNotNil(loaded);
    XCTAssertEqualObjects(loaded.code, @"inapp-1");
    XCTAssertEqualObjects(loaded.url, @"https://example.com/inapp.zip");
    XCTAssertEqual(loaded.updated, 1700000000);
}

/// Verifies the production secure-decode allowlist actually accepts nested NSArray/NSNumber/NSNull/NSDate values. Archives a dictionary holding those types under the real defaults key, then lets a fresh PWInAppStorage decode it through its own NSKeyedUnarchiver allowlist. Regression for SDK-826: dropping any of these classes from PWInAppStorage's allowlist makes the whole decode fail (resources fall back to empty), which this test catches — the PWResource round-trip above cannot, since PWResource.encodeWithCoder never serializes nested types.
- (void)testPersistence_nestedCollectionTypesSurviveSecureDecodeAllowlist {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1700000000];
    NSDictionary *persisted = @{
        @"string": @"value",
        @"array": @[@"a", @"b"],
        @"number": @42,
        @"null": [NSNull null],
        @"date": date,
        @"nested": @{ @"inner": @[@1, [NSNull null]] },
    };

    NSError *archiveError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:persisted requiringSecureCoding:YES error:&archiveError];
    XCTAssertNil(archiveError);
    XCTAssertNotNil(data);

    [[NSUserDefaults standardUserDefaults] setObject:data forKey:KeyInAppSavedResources];
    [[NSUserDefaults standardUserDefaults] synchronize];

    PWInAppStorage *storage = [PWInAppStorage new];

    XCTAssertEqual(storage.resources.count, persisted.count);
    XCTAssertEqualObjects(storage.resources[@"array"], (@[@"a", @"b"]));
    XCTAssertEqualObjects(storage.resources[@"number"], @42);
    XCTAssertEqualObjects(storage.resources[@"null"], [NSNull null]);
    XCTAssertEqualObjects(storage.resources[@"date"], date);
    XCTAssertEqualObjects(storage.resources[@"nested"][@"inner"], (@[@1, [NSNull null]]));
}

#pragma mark - Two-stage synchronization

- (void)removeLocalDataForCodes:(NSArray<NSString *> *)codes {
    for (NSString *code in codes) {
        PWResource *resource = [[PWResource alloc] initWithDictionary:@{
            @"code": code,
            @"url": @"https://example.com/x.zip",
            @"updated": @1,
        }];
        [resource deleteData];
    }
}

- (NSDictionary *)twoResourceCatalogResponse {
    return @{ @"inApps": @[
        @{@"code": @"sync-1", @"url": @"https://example.com/sync-1.zip", @"updated": @1, @"layout": @"topbanner"},
        @{@"code": @"sync-2", @"url": @"https://example.com/sync-2.zip", @"updated": @1, @"layout": @"topbanner"},
    ]};
}

- (void)drainMainQueue {
    XCTestExpectation *drained = [self expectationWithDescription:@"main queue drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [drained fulfill];
    });
    XCTAssertEqual([XCTWaiter waitForExpectations:@[drained] timeout:2], XCTWaiterResultCompleted);
}

/// Verifies that synchronizeCatalog: reports as soon as the getInApps response is stored, while every
/// resource zip is still in flight — the callback latency must not scale with the account's in-app count.
- (void)testSynchronizeCatalog_reportsBeforeResourceDownloadsFinish {
    self.mockRequestManager.defersDownloads = YES;
    self.mockRequestManager.responsesByMethod = @{ @"getInApps": [self twoResourceCatalogResponse] };

    PWInAppStorage *storage = [PWInAppStorage storage];

    __block NSError *reported = [NSError errorWithDomain:@"sentinel" code:0 userInfo:nil];
    XCTestExpectation *catalogReady = [self expectationWithDescription:@"catalog ready"];
    [storage synchronizeCatalog:^(NSError *error) {
        reported = error;
        [catalogReady fulfill];
    }];

    XCTAssertEqual([XCTWaiter waitForExpectations:@[catalogReady] timeout:2], XCTWaiterResultCompleted);
    XCTAssertNil(reported);
    XCTAssertEqual(storage.resources.count, 2u);
    XCTAssertFalse(storage.isUpdating, @"catalog gate must be open");
    XCTAssertEqual(self.mockRequestManager.downloadRequestCount, 2u, @"both zips are still downloading");

    [self.mockRequestManager releaseDownloadsWithLocation:nil error:[NSError errorWithDomain:@"pushwoosh" code:-4 userInfo:nil]];
    [self drainMainQueue];
}

/// Verifies that synchronize: keeps its old contract: it reports only once every resource zip has settled.
/// This is what reloadInAppsWithCompletion: relies on.
- (void)testSynchronize_stillWaitsForEveryResourceDownload {
    self.mockRequestManager.defersDownloads = YES;
    self.mockRequestManager.responsesByMethod = @{ @"getInApps": [self twoResourceCatalogResponse] };

    PWInAppStorage *storage = [PWInAppStorage storage];

    __block NSUInteger syncCalls = 0;
    XCTestExpectation *synced = [self expectationWithDescription:@"full sync finished"];
    [storage synchronize:^(NSError *error) {
        syncCalls++;
        [synced fulfill];
    }];

    [self drainMainQueue];

    XCTAssertEqual(syncCalls, 0u, @"synchronize: must not report while zips are still downloading");
    XCTAssertEqual(self.mockRequestManager.downloadRequestCount, 2u);

    [self.mockRequestManager releaseDownloadsWithLocation:nil error:[NSError errorWithDomain:@"pushwoosh" code:-4 userInfo:nil]];

    XCTAssertEqual([XCTWaiter waitForExpectations:@[synced] timeout:2], XCTWaiterResultCompleted);
    XCTAssertEqual(syncCalls, 1u);
    XCTAssertFalse(storage.isSyncing);
}

/// Verifies that once the catalog is known, resourcesForCode: hands back the entry while its zip is still
/// downloading — the pre-condition for the presentation path to await its own resource instead of erroring.
- (void)testResourcesForCode_returnsCatalogEntryWhileItsZipIsStillDownloading {
    self.mockRequestManager.defersDownloads = YES;
    self.mockRequestManager.responsesByMethod = @{ @"getInApps": [self twoResourceCatalogResponse] };

    PWInAppStorage *storage = [PWInAppStorage storage];

    XCTestExpectation *catalogReady = [self expectationWithDescription:@"catalog ready"];
    [storage synchronizeCatalog:^(NSError *error) {
        [catalogReady fulfill];
    }];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[catalogReady] timeout:2], XCTWaiterResultCompleted);

    __block PWResource *found = nil;
    XCTestExpectation *resolved = [self expectationWithDescription:@"resource resolved"];
    [storage resourcesForCode:@"sync-1" completionBlock:^(PWResource *resource) {
        found = resource;
        [resolved fulfill];
    }];

    XCTAssertEqual([XCTWaiter waitForExpectations:@[resolved] timeout:2], XCTWaiterResultCompleted);
    XCTAssertEqualObjects(found.code, @"sync-1");
    XCTAssertFalse([found isDownloaded]);
    XCTAssertTrue([found isDownloading]);

    [self.mockRequestManager releaseDownloadsWithLocation:nil error:[NSError errorWithDomain:@"pushwoosh" code:-4 userInfo:nil]];
    [self drainMainQueue];
}

/// Verifies that a catalog-only caller arriving mid download-phase (isUpdating == NO, isSyncing == YES)
/// is served immediately — regression for the isSyncing-only gate that stranded such callers forever.
- (void)testSynchronizeCatalog_calledDuringDownloadPhaseOfAnotherSync_reportsImmediately {
    self.mockRequestManager.defersDownloads = YES;
    self.mockRequestManager.responsesByMethod = @{ @"getInApps": [self twoResourceCatalogResponse] };

    PWInAppStorage *storage = [PWInAppStorage storage];

    __block NSUInteger fullSyncCalls = 0;
    XCTestExpectation *fullSynced = [self expectationWithDescription:@"full sync finished"];
    [storage synchronize:^(NSError *error) {
        fullSyncCalls++;
        [fullSynced fulfill];
    }];

    [self drainMainQueue];
    XCTAssertFalse(storage.isUpdating, @"catalog phase of the full sync must have completed already");
    XCTAssertTrue(storage.isSyncing, @"download phase must still be running");

    __block NSError *catalogError = [NSError errorWithDomain:@"sentinel" code:0 userInfo:nil];
    XCTestExpectation *catalogReady = [self expectationWithDescription:@"catalog-only call reports immediately"];
    [storage synchronizeCatalog:^(NSError *error) {
        catalogError = error;
        [catalogReady fulfill];
    }];

    XCTAssertEqual([XCTWaiter waitForExpectations:@[catalogReady] timeout:2], XCTWaiterResultCompleted);
    XCTAssertNil(catalogError);
    XCTAssertEqual(fullSyncCalls, 0u, @"the original full-sync waiter must still be unresolved");

    [self.mockRequestManager releaseDownloadsWithLocation:nil error:[NSError errorWithDomain:@"pushwoosh" code:-4 userInfo:nil]];

    XCTAssertEqual([XCTWaiter waitForExpectations:@[fullSynced] timeout:2], XCTWaiterResultCompleted);
    XCTAssertEqual(fullSyncCalls, 1u);
}

@end
