#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWSessionRetrySender.h"
#import "PWRetryPolicy.h"
#import "PWRequestManager.h"
#import "PWRequest.h"

@interface PWSessionRetrySenderTest : XCTestCase
@property (nonatomic) id mockRequestManager;
@property (nonatomic) PWSessionRetrySender *sender;
@end

@implementation PWSessionRetrySenderTest

- (void)setUp {
    self.mockRequestManager = OCMClassMock([PWRequestManager class]);
    self.sender = [[PWSessionRetrySender alloc] initWithRequestManager:self.mockRequestManager
                                                                policy:[PWRetryPolicy new]];
    self.sender.retryDelaysSeconds = @[@0, @0];
}

- (void)tearDown {
    [self.mockRequestManager stopMocking];
}

- (void)stubSendReturningError:(NSError *)error httpCode:(NSInteger)code counter:(int *)counter {
    OCMStub([self.mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        (*counter)++;
        __unsafe_unretained PWRequest *req = nil;
        [invocation getArgument:&req atIndex:2];
        req.httpCode = code;
        __unsafe_unretained void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) completion(error);
    });
}

- (void)stubTransientFailures:(int)failCount thenSuccessCapturing:(NSMutableArray *)received counter:(int *)counter {
    NSError *timeout = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    OCMStub([self.mockRequestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained PWRequest *req = nil;
        [invocation getArgument:&req atIndex:2];
        if (received) [received addObject:req];
        BOOL fail = (*counter) < failCount;
        (*counter)++;
        req.httpCode = fail ? 0 : 200;
        __unsafe_unretained void (^completion)(NSError *) = nil;
        [invocation getArgument:&completion atIndex:3];
        if (completion) completion(fail ? timeout : nil);
    });
}

/// Verifies a successful send is delivered immediately with a single attempt.
- (void)testSuccess_singleAttempt {
    __block int calls = 0;
    [self stubSendReturningError:nil httpCode:200 counter:&calls];

    XCTestExpectation *exp = [self expectationWithDescription:@"done"];
    [self.sender sendWithRetry:[PWRequest new] completion:^(NSError *error) {
        XCTAssertNil(error);
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(calls, 1);
}

/// Verifies a transient failure is retried up to retryDelaysSeconds.count, then gives up with the error.
- (void)testTransientFailure_retriesThenGivesUp {
    __block int calls = 0;
    NSError *timeout = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [self stubSendReturningError:timeout httpCode:0 counter:&calls];

    XCTestExpectation *exp = [self expectationWithDescription:@"done"];
    [self.sender sendWithRetry:[PWRequest new] completion:^(NSError *error) {
        XCTAssertNotNil(error);
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(calls, 3);
}

/// Verifies a non-retriable failure (4xx) is delivered immediately without retrying.
- (void)testPermanentFailure_noRetry {
    __block int calls = 0;
    NSError *badRequest = [NSError errorWithDomain:@"PushwooshErrorDomain" code:1 userInfo:nil];
    [self stubSendReturningError:badRequest httpCode:400 counter:&calls];

    XCTestExpectation *exp = [self expectationWithDescription:@"done"];
    [self.sender sendWithRetry:[PWRequest new] completion:^(NSError *error) {
        XCTAssertNotNil(error);
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(calls, 1);
}

/// Verifies a transient failure followed by a success completes with no error after retrying.
- (void)testRecoversAfterTransientFailures {
    __block int calls = 0;
    [self stubTransientFailures:2 thenSuccessCapturing:nil counter:&calls];

    XCTestExpectation *exp = [self expectationWithDescription:@"done"];
    [self.sender sendWithRetry:[PWRequest new] completion:^(NSError *error) {
        XCTAssertNil(error);
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(calls, 3);
}

/// Verifies completion is invoked exactly once even when every attempt fails (no double callback).
- (void)testCompletionCalledExactlyOnce_onExhaustion {
    __block int calls = 0;
    NSError *timeout = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [self stubSendReturningError:timeout httpCode:0 counter:&calls];

    XCTestExpectation *exp = [self expectationWithDescription:@"completion once"];
    [self.sender sendWithRetry:[PWRequest new] completion:^(NSError *error) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
}

/// Verifies every retry re-sends the exact same request instance (payload is rebuilt fresh per attempt).
- (void)testSameRequestInstanceReusedAcrossAttempts {
    PWRequest *original = [PWRequest new];
    __block int calls = 0;
    NSMutableArray *received = [NSMutableArray array];
    [self stubTransientFailures:2 thenSuccessCapturing:received counter:&calls];

    XCTestExpectation *exp = [self expectationWithDescription:@"done"];
    [self.sender sendWithRetry:original completion:^(NSError *error) {
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(received.count, 3);
    for (PWRequest *sent in received) {
        XCTAssertTrue(sent == original);
    }
}

/// Verifies the retry count honours retryDelaysSeconds.count (one delay → at most one retry).
- (void)testRespectsConfiguredRetryCount {
    self.sender.retryDelaysSeconds = @[@0];
    __block int calls = 0;
    NSError *timeout = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [self stubSendReturningError:timeout httpCode:0 counter:&calls];

    XCTestExpectation *exp = [self expectationWithDescription:@"done"];
    [self.sender sendWithRetry:[PWRequest new] completion:^(NSError *error) {
        XCTAssertNotNil(error);
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(calls, 2);
}

/// Verifies a nil completion does not crash while retries are exhausted.
- (void)testNilCompletion_doesNotCrash {
    __block int calls = 0;
    NSError *timeout = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [self stubSendReturningError:timeout httpCode:0 counter:&calls];

    [self.sender sendWithRetry:[PWRequest new] completion:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"drain"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [exp fulfill];
    });
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(calls, 3);
}

@end
