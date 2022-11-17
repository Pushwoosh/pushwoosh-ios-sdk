
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

/**
 * Get tags from cold start
 */
- (void)testInitialGetTags {
	NSDictionary *tags = [[PWCache cache] getTags];
	XCTAssertNil(tags, @"Initail cached tags must be nil");
}

/**
 * Get tags after setting tags
 */
- (void)testGetTags {
	NSDictionary *inputTags = @{ @"testIntTag" : @1, @"testStringTag" : @"testString", @"testListTag" : @[ @1, @"coockie", @YES] };
	[[PWCache cache] setTags:inputTags];
	NSDictionary *outputTags = [[PWCache cache] getTags];
	XCTAssertTrue([inputTags isEqualToDictionary:outputTags], @"Output tags does not match input");
}

/**
 * Get tags after setting tags twice
 */
- (void)testGetTags2 {
	NSDictionary *inputTags1 = @{ @"testIntTag" : @1, @"testStringTag" : @"testString4" };
	[[PWCache cache] setTags:inputTags1];
	NSDictionary *inputTags2 = @{ @"testListTag" : @[ @1, @"coockie", @YES] };
	[[PWCache cache] setTags:inputTags2];
	
	NSDictionary *outputTags = [[PWCache cache] getTags];
	XCTAssertTrue([outputTags isEqualToDictionary:inputTags2], @"Output tags does not match input");
}

/**
 * Add tags from cold start
 */
- (void)testInitialAddTags {
	NSDictionary *inputTags = @{ @"testIntTag" : @1, @"testStringTag" : @"testString", @"testListTag" : @[ @1, @"coockie", @YES] };
	[[PWCache cache] addTags:inputTags];
	NSDictionary *outputTags = [[PWCache cache] getTags];
	XCTAssertTrue([outputTags isEqualToDictionary:inputTags], @"Output tags (%@) does not match input (%@)", outputTags, inputTags);
}

/**
 * Add tags after setting tags
 */
- (void)testAddTags {
	NSDictionary *inputTags1 = @{ @"testIntTag" : @1, @"testStringTag" : @"testString5" };
	[[PWCache cache] setTags:inputTags1];
	NSDictionary *inputTags2 = @{ @"testListTag" : @[ @1, @"coockie", @YES] };
	[[PWCache cache] addTags:inputTags2];
	
	NSDictionary *expectedTags = @{ @"testIntTag" : @1, @"testStringTag" : @"testString5", @"testListTag" : @[ @1, @"coockie", @YES] };
	NSDictionary *outputTags = [[PWCache cache] getTags];
	XCTAssertTrue([outputTags isEqualToDictionary:expectedTags], @"Output tags does not match input");
}

/**
 * Get tags from cache
 */
- (void)testGetCacheTags {
	NSDictionary *inputTags = @{ @"testIntTag" : @1, @"testStringTag" : @"testString", @"testListTag" : @[ @1, @"coockie", @YES] };
	[PWTestUtils writeCacheTags:inputTags];
	NSDictionary *outputTags = [[PWCache cache] getTags];
	XCTAssertTrue([outputTags isEqualToDictionary:inputTags], @"Output tags (%@) does not match input (%@)", outputTags, inputTags);
}

/**
 * Stress test. Get tags from corrupted cache
 */
- (void)testStressGetTags {
	[PWTestUtils writeCacheTags:@[]];
	NSDictionary *tags = [[PWCache cache] getTags];
	XCTAssertNil(tags, @"Initail cached tags must be nil");
}

/**
 * Stress test. Add tags to corrupted cache
 */
- (void)testStressAddTags {
	[PWTestUtils writeCacheTags:@[]];
	NSDictionary *inputTags = @{ @"testIntTag" : @1, @"testStringTag" : @"testString", @"testListTag" : @[ @1, @"coockie", @YES] };
	[[PWCache cache] addTags:inputTags];
	NSDictionary *outputTags = [[PWCache cache] getTags];
	XCTAssertTrue([outputTags isEqualToDictionary:inputTags], @"Output tags (%@) does not match input (%@)", outputTags, inputTags);
}

@end
