
#import "PWCache.h"
#import "PWTestUtils.h"

#import <XCTest/XCTest.h>

@interface PWCacheTest : XCTestCase

@property (nonatomic, strong) NSString *cacheFile;

@end

@implementation PWCacheTest

- (void)setUp {
    [super setUp];
	[[PWCache cache] clear];
}

- (void)tearDown {
    [[PWCache cache] clear];
    [super tearDown];
}

/// Verifies that getTags on a cold cache returns nil.
- (void)testInitialGetTags {
    XCTAssertNil([[PWCache cache] getTags]);
}

/// Verifies that setTags persists the dictionary so getTags returns an equal value.
- (void)testGetTags {
    NSDictionary *inputTags = @{ @"testIntTag" : @1, @"testStringTag" : @"testString", @"testListTag" : @[ @1, @"coockie", @YES] };
    [[PWCache cache] setTags:inputTags];

    XCTAssertEqualObjects([[PWCache cache] getTags], inputTags);
}

/// Verifies that setTags replaces (not merges) the previously cached dictionary.
- (void)testGetTags2 {
    NSDictionary *inputTags1 = @{ @"testIntTag" : @1, @"testStringTag" : @"testString4" };
    [[PWCache cache] setTags:inputTags1];
    NSDictionary *inputTags2 = @{ @"testListTag" : @[ @1, @"coockie", @YES] };
    [[PWCache cache] setTags:inputTags2];

    XCTAssertEqualObjects([[PWCache cache] getTags], inputTags2);
}

/// Verifies that addTags on a cold cache writes the dictionary verbatim.
- (void)testInitialAddTags {
    NSDictionary *inputTags = @{ @"testIntTag" : @1, @"testStringTag" : @"testString", @"testListTag" : @[ @1, @"coockie", @YES] };
    [[PWCache cache] addTags:inputTags];

    XCTAssertEqualObjects([[PWCache cache] getTags], inputTags);
}

/// Verifies that addTags merges new keys into the previously cached dictionary instead of replacing it.
- (void)testAddTags {
    NSDictionary *inputTags1 = @{ @"testIntTag" : @1, @"testStringTag" : @"testString5" };
    [[PWCache cache] setTags:inputTags1];
    NSDictionary *inputTags2 = @{ @"testListTag" : @[ @1, @"coockie", @YES] };
    [[PWCache cache] addTags:inputTags2];

    NSDictionary *expectedTags = @{ @"testIntTag" : @1, @"testStringTag" : @"testString5", @"testListTag" : @[ @1, @"coockie", @YES] };
    XCTAssertEqualObjects([[PWCache cache] getTags], expectedTags);
}

/// Verifies that getTags can read tags previously archived to disk via the cache writer.
- (void)testGetCacheTags {
    NSDictionary *inputTags = @{ @"testIntTag" : @1, @"testStringTag" : @"testString", @"testListTag" : @[ @1, @"coockie", @YES] };
    [PWTestUtils writeCacheTags:inputTags];

    XCTAssertEqualObjects([[PWCache cache] getTags], inputTags);
}

/// Verifies that getTags handles a corrupted on-disk cache (array instead of dict) by returning nil.
- (void)testStressGetTags {
    [PWTestUtils writeCacheTags:@[]];

    XCTAssertNil([[PWCache cache] getTags]);
}

/// Verifies that addTags after a corrupted on-disk cache recovers and stores the new dictionary.
- (void)testStressAddTags {
    [PWTestUtils writeCacheTags:@[]];
    NSDictionary *inputTags = @{ @"testIntTag" : @1, @"testStringTag" : @"testString", @"testListTag" : @[ @1, @"coockie", @YES] };
    [[PWCache cache] addTags:inputTags];

    XCTAssertEqualObjects([[PWCache cache] getTags], inputTags);
}

/// Verifies that tags containing NSNull values round-trip through the secure-decode allowlist without loss.
- (void)testGetTagsWithNSNull {
    NSDictionary *inputTags = @{ @"intTag" : @42, @"stringTag" : @"hello", @"nullTag" : [NSNull null], @"listTag" : @[ @1, @"foo", [NSNull null] ] };
    [[PWCache cache] setTags:inputTags];

    XCTAssertEqualObjects([[PWCache cache] getTags], inputTags);
}

/// Verifies that tags containing NSDate values round-trip through the secure-decode allowlist without loss.
- (void)testGetTagsWithNSDate {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1700000000];
    NSDictionary *inputTags = @{ @"dateTag" : date, @"stringTag" : @"value" };
    [[PWCache cache] setTags:inputTags];

    XCTAssertEqualObjects([[PWCache cache] getTags], inputTags);
}

/// Verifies that a zero-length cache file does not crash and is treated as an empty cache.
- (void)testZeroLengthCacheFileReturnsNil {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *file = [paths.firstObject stringByAppendingPathComponent:@"pwtags"];
    [[NSData data] writeToFile:file atomically:YES];

    XCTAssertNil([[PWCache cache] getTags]);
}

/// Verifies that addTags recovers from a zero-length cache file and persists the new dictionary.
- (void)testAddTagsRecoversFromZeroLengthFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *file = [paths.firstObject stringByAppendingPathComponent:@"pwtags"];
    [[NSData data] writeToFile:file atomically:YES];

    NSDictionary *inputTags = @{ @"intTag" : @1, @"stringTag" : @"recovered" };
    [[PWCache cache] addTags:inputTags];

    XCTAssertEqualObjects([[PWCache cache] getTags], inputTags);
}

@end
