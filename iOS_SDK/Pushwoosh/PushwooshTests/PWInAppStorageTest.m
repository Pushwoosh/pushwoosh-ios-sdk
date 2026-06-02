#import <XCTest/XCTest.h>

#import "PWInAppStorage.h"
#import "PWResource.h"

static NSString *const KeyInAppSavedResources = @"InAppSavedResources";

@interface PWInAppStorage (Test)

@property (atomic, strong) NSDictionary *resources;

@end

@interface PWInAppStorageTest : XCTestCase

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
}

- (void)tearDown {
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

@end
