#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWRequestsCacheManager.h"
#import "PWCachedRequest.h"
#import "PWRequest.h"

@interface PWRequestsCacheManager (Test)

- (NSString *)getCachePath;
- (void)save:(NSMutableArray *)requestsQueue withPath:(NSString *)path;
@property (nonatomic) NSMutableArray *requestsQueue;

@end

@interface PWRequestsCacheManagerTest : XCTestCase

@end

@implementation PWRequestsCacheManagerTest

#pragma mark - Helpers

+ (NSString *)cachePath {
    NSArray *urls = [[NSFileManager new] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    return [[(NSURL *)urls.firstObject path] stringByAppendingPathComponent:@"PWRequestCache"];
}

+ (void)removeCacheFile {
    [[NSFileManager new] removeItemAtPath:[self cachePath] error:nil];
}

- (void)setUp {
    [super setUp];
    [self.class removeCacheFile];
}

- (void)tearDown {
    [self.class removeCacheFile];
    [super tearDown];
}

- (PWCachedRequest *)makeCachedRequestWithMethod:(NSString *)method
                                      identifier:(NSString *)identifier
                                      dictionary:(NSDictionary *)dict {
    id mockRequest = OCMClassMock([PWRequest class]);
    OCMStub([mockRequest methodName]).andReturn(method);
    OCMStub([mockRequest requestIdentifier]).andReturn(identifier);
    OCMStub([mockRequest requestDictionary]).andReturn(dict);
    PWCachedRequest *cached = [[PWCachedRequest alloc] initWithRequest:mockRequest];
    [mockRequest stopMocking];
    return cached;
}

#pragma mark - Singleton

/// Verifies that sharedInstance returns the same instance across calls.
- (void)testSharedInstance_isSingleton {
    PWRequestsCacheManager *a = [PWRequestsCacheManager sharedInstance];
    PWRequestsCacheManager *b = [PWRequestsCacheManager sharedInstance];

    XCTAssertNotNil(a);
    XCTAssertEqual(a, b);
}

#pragma mark - Persistence round-trip

/// Verifies that a cached request with a realistic payload (NSArray + NSNumber + nested NSDictionary) saved through one manager instance is correctly read back by a fresh instance. Regression for SDK-826: secure-decode allowlist had to be expanded to cover nested types or the entire offline queue would be silently dropped.
- (void)testSavedQueueIsReloadedWithNestedArrayAndDictPayload {
    PWRequestsCacheManager *manager = [PWRequestsCacheManager new];
    [manager.requestsQueue removeAllObjects];

    PWCachedRequest *req = [self makeCachedRequestWithMethod:@"setTags"
                                                  identifier:@"req-tags-1"
                                                  dictionary:@{
        @"appCode": @"XXXXX-12345",
        @"tags": @[@"premium", @"newsletter"],
        @"counters": @[@1, @2, @3],
        @"nested": @{@"flag": @YES},
    }];
    [manager.requestsQueue addObject:req];
    [manager save:manager.requestsQueue withPath:[manager getCachePath]];

    PWRequestsCacheManager *freshManager = [PWRequestsCacheManager new];
    NSMutableArray *loaded = freshManager.requestsQueue;

    XCTAssertEqual(loaded.count, 1u);
    PWCachedRequest *loadedReq = loaded.firstObject;
    XCTAssertEqualObjects(loadedReq.methodName, @"setTags");
    XCTAssertEqualObjects(loadedReq.requestIdentifier, @"req-tags-1");
    XCTAssertTrue([loadedReq.requestDictionary[@"tags"] isKindOfClass:[NSArray class]]);
    XCTAssertEqual([loadedReq.requestDictionary[@"tags"] count], 2u);
    XCTAssertEqualObjects(loadedReq.requestDictionary[@"appCode"], @"XXXXX-12345");
}

/// Verifies that loading from a non-existent cache file yields an empty queue (clean install / cache cleared).
- (void)testRequestsQueue_noCacheFile_returnsEmptyQueue {
    [self.class removeCacheFile];

    PWRequestsCacheManager *manager = [PWRequestsCacheManager new];

    XCTAssertNotNil(manager.requestsQueue);
    XCTAssertEqual(manager.requestsQueue.count, 0u);
}

/// Verifies that loading from a zero-length cache file (e.g. interrupted prior save) yields an empty queue rather than throwing on the unarchiver. Regression for SDK-826: previously a zero-byte file would pass the nil-check and crash the unarchiver with "data parameter is nil".
- (void)testRequestsQueue_emptyCacheFile_returnsEmptyQueueWithoutCrash {
    [@"" writeToFile:[self.class cachePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];

    PWRequestsCacheManager *manager = [PWRequestsCacheManager new];

    XCTAssertNotNil(manager.requestsQueue);
    XCTAssertEqual(manager.requestsQueue.count, 0u);
}

@end
