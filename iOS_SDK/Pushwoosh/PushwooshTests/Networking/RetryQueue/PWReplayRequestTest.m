#import <XCTest/XCTest.h>
#import "PWReplayRequest.h"
#import "PWRequest.h"

@interface PWReplayRequestTest : XCTestCase
@end

@implementation PWReplayRequestTest

/// Verifies the replay request returns the frozen methodName and requestDictionary verbatim and preserves the identifier.
- (void)testReplayPreservesFrozenFields {
    NSDictionary *dict = @{@"hwid": @"abc", @"hash": @"xyz"};
    PWReplayRequest *request = [[PWReplayRequest alloc] initWithMethodName:@"pushStat"
                                                        requestDictionary:dict
                                                        requestIdentifier:@"id-123"];

    XCTAssertEqualObjects(request.methodName, @"pushStat");
    XCTAssertEqualObjects(request.requestDictionary, dict);
    XCTAssertEqualObjects(request.requestIdentifier, @"id-123");
}

/// Verifies a replayed request is NOT cacheable, so a re-failure is handled by the retry queue rather than re-enqueued by the manager (prevents an infinite persist loop).
- (void)testReplayIsNotCacheable {
    PWReplayRequest *request = [[PWReplayRequest alloc] initWithMethodName:@"pushStat"
                                                        requestDictionary:@{}
                                                        requestIdentifier:@"id-1"];

    XCTAssertFalse(request.cacheable);
}

/// Verifies the convenience initializer defaults to the standard transport (wrap on, no base URL override).
- (void)testReplayDefaultsToStandardTransport {
    PWReplayRequest *request = [[PWReplayRequest alloc] initWithMethodName:@"pushStat"
                                                        requestDictionary:@{}
                                                        requestIdentifier:@"id-1"];

    XCTAssertTrue(request.shouldWrapRequest);
    XCTAssertNil(request.baseUrl);
}

/// Verifies the frozen shouldWrapRequest/baseUrl are returned verbatim so the replay is serialized and routed like the original send.
- (void)testReplayPreservesTransportOverrides {
    PWReplayRequest *request = [[PWReplayRequest alloc] initWithMethodName:@"pushStat"
                                                        requestDictionary:@{}
                                                        requestIdentifier:@"id-1"
                                                        shouldWrapRequest:NO
                                                                  baseUrl:@"https://custom.example.com/"];

    XCTAssertFalse(request.shouldWrapRequest);
    XCTAssertEqualObjects(request.baseUrl, @"https://custom.example.com/");
}

@end
