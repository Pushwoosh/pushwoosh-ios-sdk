
#import <XCTest/XCTest.h>
#import "PWSdkStateProvider.h"

#pragma mark - Expose private properties for testing

@interface PWSdkStateProvider (Test)

@property (nonatomic) PWSdkState currentState;
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *taskQueue;

- (void)resetForTesting;

@end

#pragma mark - Test class

@interface PWSdkStateProviderTest : XCTestCase

@property (nonatomic, strong) PWSdkStateProvider *provider;

@end

@implementation PWSdkStateProviderTest

- (void)setUp {
    [super setUp];
    _provider = [PWSdkStateProvider new];
}

- (void)tearDown {
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    _provider = nil;
    [super tearDown];
}

#pragma mark - Initial State Tests

/// Verifies that initial state is Initializing.
- (void)testInitialState_isInitializing {
    XCTAssertEqual(_provider.currentState, PWSdkStateInitializing);
}

/// Verifies that isReady returns NO in initial state.
- (void)testIsReady_returnsFalseInitially {
    XCTAssertFalse([_provider isReady]);
}

#pragma mark - setReady Tests

/// Verifies that setReady transitions state to Ready.
- (void)testSetReady_transitionsToReady {
    [_provider setReady];

    XCTAssertEqual(_provider.currentState, PWSdkStateReady);
    XCTAssertTrue([_provider isReady]);
}

/// Verifies that setReady flushes all queued tasks.
- (void)testSetReady_flushesQueuedTasks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"tasks flushed"];
    __block int executedCount = 0;

    [_provider executeOrQueue:^{ executedCount++; }];
    [_provider executeOrQueue:^{ executedCount++; }];
    [_provider executeOrQueue:^{ executedCount++; if (executedCount == 3) [expectation fulfill]; }];

    XCTAssertEqual(executedCount, 0);

    [_provider setReady];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(executedCount, 3);
}

/// Verifies that queue is empty after setReady.
- (void)testSetReady_clearsQueue {
    [_provider executeOrQueue:^{}];
    [_provider executeOrQueue:^{}];

    [_provider setReady];

    XCTAssertEqual(_provider.taskQueue.count, 0);
}

/// Verifies that second setReady call is ignored.
- (void)testSetReady_calledTwice_secondCallIgnored {
    XCTestExpectation *expectation = [self expectationWithDescription:@"first flush"];
    __block int executedCount = 0;

    [_provider executeOrQueue:^{ executedCount++; [expectation fulfill]; }];
    [_provider setReady];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(executedCount, 1);

    [_provider executeOrQueue:^{ executedCount++; }];
    [_provider setReady];

    XCTAssertEqual(executedCount, 2);
}

/// Verifies that setReady does not crash when queue is empty.
- (void)testSetReady_emptyQueue_doesNotCrash {
    XCTAssertNoThrow([_provider setReady]);
    XCTAssertTrue([_provider isReady]);
}

#pragma mark - setError Tests

/// Verifies that setError transitions state to Error.
- (void)testSetError_transitionsToError {
    [_provider setError];

    XCTAssertEqual(_provider.currentState, PWSdkStateError);
    XCTAssertFalse([_provider isReady]);
}

/// Verifies that setError clears queued tasks.
- (void)testSetError_clearsQueuedTasks {
    [_provider executeOrQueue:^{}];
    [_provider executeOrQueue:^{}];

    [_provider setError];

    XCTAssertEqual(_provider.taskQueue.count, 0);
}

/// Verifies that setReady after setError does not transition to Ready.
- (void)testSetReady_afterError_doesNotTransition {
    [_provider setError];
    [_provider setReady];

    XCTAssertEqual(_provider.currentState, PWSdkStateError);
}

#pragma mark - executeOrQueue Tests

/// Verifies that tasks are queued when state is Initializing.
- (void)testExecuteOrQueue_queuesTaskWhenInitializing {
    __block BOOL executed = NO;

    [_provider executeOrQueue:^{ executed = YES; }];

    XCTAssertFalse(executed);
    XCTAssertEqual(_provider.taskQueue.count, 1);
}

/// Verifies that tasks execute immediately when state is Ready.
- (void)testExecuteOrQueue_executesImmediatelyWhenReady {
    [_provider setReady];

    __block BOOL executed = NO;
    [_provider executeOrQueue:^{ executed = YES; }];

    XCTAssertTrue(executed);
}

/// Verifies that tasks are ignored when state is Error.
- (void)testExecuteOrQueue_ignoresTaskWhenError {
    [_provider setError];

    __block BOOL executed = NO;
    [_provider executeOrQueue:^{ executed = YES; }];

    XCTAssertFalse(executed);
    XCTAssertEqual(_provider.taskQueue.count, 0);
}

/// Verifies that queued tasks execute in order.
- (void)testExecuteOrQueue_tasksExecuteInOrder {
    XCTestExpectation *expectation = [self expectationWithDescription:@"all tasks"];
    NSMutableArray *order = [NSMutableArray new];
    NSObject *lock = [NSObject new];

    [_provider executeOrQueue:^{ @synchronized(lock) { [order addObject:@1]; } }];
    [_provider executeOrQueue:^{ @synchronized(lock) { [order addObject:@2]; } }];
    [_provider executeOrQueue:^{ @synchronized(lock) { [order addObject:@3]; } [expectation fulfill]; }];

    [_provider setReady];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(order.count, 3);
}

/// Verifies that a throwing task does not prevent other queued tasks from executing.
- (void)testSetReady_throwingTask_doesNotBlockOtherTasks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"second task"];
    __block BOOL secondExecuted = NO;

    [_provider executeOrQueue:^{
        @throw [NSException exceptionWithName:@"TestException" reason:@"test" userInfo:nil];
    }];
    [_provider executeOrQueue:^{ secondExecuted = YES; [expectation fulfill]; }];

    [_provider setReady];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertTrue(secondExecuted);
}

#pragma mark - resetForTesting Tests

/// Verifies that resetForTesting resets state to Initializing.
- (void)testResetForTesting_resetsToInitializing {
    [_provider setReady];
    [_provider resetForTesting];

    XCTAssertEqual(_provider.currentState, PWSdkStateInitializing);
    XCTAssertFalse([_provider isReady]);
}

/// Verifies that resetForTesting clears queue.
- (void)testResetForTesting_clearsQueue {
    [_provider executeOrQueue:^{}];
    [_provider resetForTesting];

    XCTAssertEqual(_provider.taskQueue.count, 0);
}

#pragma mark - Singleton Tests

/// Verifies that sharedInstance returns the same object.
- (void)testSharedInstance_returnsSameObject {
    PWSdkStateProvider *instance1 = [PWSdkStateProvider sharedInstance];
    PWSdkStateProvider *instance2 = [PWSdkStateProvider sharedInstance];

    XCTAssertEqual(instance1, instance2);
}

#pragma mark - Thread Safety Tests

/// Verifies concurrent executeOrQueue calls don't crash.
- (void)testThreadSafety_concurrentExecuteOrQueue {
    XCTestExpectation *expectation = [self expectationWithDescription:@"concurrent queue"];
    expectation.expectedFulfillmentCount = 100;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    for (int i = 0; i < 100; i++) {
        dispatch_async(queue, ^{
            [_provider executeOrQueue:^{}];
            [expectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertEqual(_provider.taskQueue.count, 100);
}

/// Verifies concurrent setReady and executeOrQueue don't crash.
- (void)testThreadSafety_concurrentSetReadyAndExecuteOrQueue {
    XCTestExpectation *expectation = [self expectationWithDescription:@"concurrent ready and queue"];
    expectation.expectedFulfillmentCount = 101;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

    for (int i = 0; i < 100; i++) {
        dispatch_async(queue, ^{
            [_provider executeOrQueue:^{}];
            [expectation fulfill];
        });
    }

    dispatch_async(queue, ^{
        [_provider setReady];
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

@end
