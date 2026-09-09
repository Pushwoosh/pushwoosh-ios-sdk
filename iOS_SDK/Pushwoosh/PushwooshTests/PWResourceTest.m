#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWResource.h"
#import "PWCache.h"
#import "PWConfig.h"
#import "PWNetworkModule.h"
#import "PWRequestManagerMock.h"

@interface PWResourceTest : XCTestCase

@property (nonatomic, strong) id cacheMock;
@property (nonatomic, strong) id configMock;
@property (nonatomic, strong) PWRequestManagerMock *mockRequestManager;
@property (nonatomic, strong) PWRequestManager *originalRequestManager;

@end

@implementation PWResourceTest

- (void)setUp {
    [super setUp];
    self.originalRequestManager = [PWNetworkModule module].requestManager;
    self.mockRequestManager = [PWRequestManagerMock new];
    [PWNetworkModule module].requestManager = self.mockRequestManager;
}

- (void)tearDown {
    [PWNetworkModule module].requestManager = self.originalRequestManager;
    PWResource *leftover = [[PWResource alloc] initWithDictionary:[PWResourceTest dict]];
    [leftover deleteData];
    /// PWCache and PWConfig are singletons, so a partial mock left standing would leak into every later suite.
    [self.cacheMock stopMocking];
    self.cacheMock = nil;
    [self.configMock stopMocking];
    self.configMock = nil;
    [super tearDown];
}

+ (NSDictionary *)dict {
    static NSDictionary *dictionary;
    if (dictionary == nil) {
        dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                      @"topbanner", @"layout",
                      @1234567890, @"updated",
                      @"1q2w3e4r5t6y7u8", @"hash",
                      @"AAAAA-11111", @"code",
                      @0, @"closeButtonType",
                      @"https://fakeurl.com/11111-AAAAA", @"url",
                      nil];
    }
    return dictionary;
}

/// Verifies that postProcessPageWithContent substitutes localized-string and dynamic-content placeholders with their default values.
- (void)testPostProcessPageWithContent {
    PWResource *resource = [[PWResource alloc] initWithDictionary:[PWResourceTest dict]];
    NSString *pageContent = @"{{LocalizedString1|text|testvalue1}}, {{LocalizedString2|text|testvalue2}}, {{tag3|templateValue3}}, {DynamicContent|String|DefaultDynamicValue}, {DynamicContent|String|}, {DynamicContentValue|String|Default}";
    NSString *content = [resource postProcessPageWithContent:pageContent];
    NSString *expected = @"testvalue1, testvalue2, tag3, DefaultDynamicValue, , Default";

    XCTAssertEqualObjects(content, expected);
}

/// Verifies the HTML path leaves device tags out when there is neither a payload tag dictionary nor a tag cache, so a shipped creative keeps rendering its default.
- (void)testPostProcessPageKeepsDeviceTagsOutWhenThereIsNoTagSourceAtAll {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(nil);
    /// Flags forced on so the assertion rests on the nil dictionary, not on the test bundle's plist.
    self.configMock = OCMPartialMock([PWConfig config]);
    OCMStub([self.configMock allowCollectingDeviceModel]).andReturn(YES);
    OCMStub([self.configMock allowCollectingDeviceOsVersion]).andReturn(YES);
    PWResource *resource = [[PWResource alloc] initWithDictionary:[PWResourceTest dict]];

    NSString *content = [resource postProcessPageWithContent:@"{Device Model|text|Fallback}"];

    XCTAssertEqualObjects(content, @"Fallback");
}

/// Verifies that awaiting an already-unpacked resource reports success without touching the network.
- (void)testAwaitDownload_alreadyDownloaded_reportsImmediatelyWithoutADownload {
    PWResource *resource = [[PWResource alloc] initWithDictionary:[PWResourceTest dict]];
    [[NSFileManager defaultManager] createDirectoryAtPath:[resource localPath] withIntermediateDirectories:YES attributes:nil error:nil];
    XCTAssertTrue([resource isDownloaded]);

    __block NSUInteger calls = 0;
    __block NSError *reported = [NSError errorWithDomain:@"sentinel" code:0 userInfo:nil];
    [resource awaitDownloadWithCompletion:^(NSError *error) {
        calls++;
        reported = error;
    }];

    XCTAssertEqual(calls, 1u);
    XCTAssertNil(reported);
    XCTAssertEqual(self.mockRequestManager.downloadRequestCount, 0u);
}

/// Verifies that awaiting a resource whose zip is already in flight waits for that download instead of
/// reporting "not downloaded yet", and does not kick off a second download of the same url.
- (void)testAwaitDownload_whileDownloading_waitsForTheRunningDownload {
    self.mockRequestManager.defersDownloads = YES;

    PWResource *resource = [[PWResource alloc] initWithDictionary:[PWResourceTest dict]];
    [resource deleteData];
    XCTAssertFalse([resource isDownloaded]);

    [resource downloadDataWithCompletion:^(NSError *error) {}];

    XCTAssertTrue([resource isDownloading]);
    XCTAssertEqual(self.mockRequestManager.downloadRequestCount, 1u);

    __block NSUInteger awaitCalls = 0;
    __block NSError *awaitError = nil;
    XCTestExpectation *awaited = [self expectationWithDescription:@"await completed"];
    [resource awaitDownloadWithCompletion:^(NSError *error) {
        awaitCalls++;
        awaitError = error;
        [awaited fulfill];
    }];

    XCTAssertEqual(awaitCalls, 0u, @"must not report before the running download finishes");
    XCTAssertEqual(self.mockRequestManager.downloadRequestCount, 1u, @"must not start a second download");

    NSError *transportError = [NSError errorWithDomain:@"pushwoosh" code:-3 userInfo:@{NSLocalizedDescriptionKey : @"parked download failed"}];
    [self.mockRequestManager releaseDownloadsWithLocation:nil error:transportError];

    XCTAssertEqual([XCTWaiter waitForExpectations:@[awaited] timeout:2], XCTWaiterResultCompleted);
    XCTAssertEqual(awaitCalls, 1u);
    XCTAssertEqualObjects(awaitError.domain, transportError.domain);
    XCTAssertEqual(self.mockRequestManager.downloadRequestCount, 1u);
    XCTAssertFalse([resource isDownloading]);
}

/// Verifies that two overlapping first callers on the same resource collapse into a single download
/// instead of racing two zip downloads into the same localPath (the check-and-flip must be atomic).
- (void)testAwaitDownload_concurrentFirstCallers_startExactlyOneDownload {
    self.mockRequestManager.defersDownloads = YES;

    PWResource *resource = [[PWResource alloc] initWithDictionary:[PWResourceTest dict]];
    [resource deleteData];
    XCTAssertFalse([resource isDownloaded]);

    __block NSUInteger firstCalls = 0;
    __block NSUInteger secondCalls = 0;
    XCTestExpectation *firstDone = [self expectationWithDescription:@"first await completed"];
    XCTestExpectation *secondDone = [self expectationWithDescription:@"second await completed"];

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);

    dispatch_group_async(group, concurrentQueue, ^{
        [resource awaitDownloadWithCompletion:^(NSError *error) {
            firstCalls++;
            [firstDone fulfill];
        }];
    });
    dispatch_group_async(group, concurrentQueue, ^{
        [resource awaitDownloadWithCompletion:^(NSError *error) {
            secondCalls++;
            [secondDone fulfill];
        }];
    });

    long groupWaitResult = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
    XCTAssertEqual(groupWaitResult, 0l);
    XCTAssertEqual(self.mockRequestManager.downloadRequestCount, 1u, @"must not start a second download for the same resource");

    NSError *transportError = [NSError errorWithDomain:@"pushwoosh" code:-3 userInfo:@{NSLocalizedDescriptionKey : @"parked download failed"}];
    [self.mockRequestManager releaseDownloadsWithLocation:nil error:transportError];

    NSArray<XCTestExpectation *> *bothExpectations = @[firstDone, secondDone];
    XCTAssertEqual([XCTWaiter waitForExpectations:bothExpectations timeout:2], XCTWaiterResultCompleted);
    XCTAssertEqual(firstCalls, 1u);
    XCTAssertEqual(secondCalls, 1u);
    XCTAssertEqual(self.mockRequestManager.downloadRequestCount, 1u);
}

@end
