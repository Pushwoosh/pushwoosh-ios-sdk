#import <XCTest/XCTest.h>

#import "PWUtils.h"

@interface PWUtilsMobileMergeTest : XCTestCase
@end

@implementation PWUtilsMobileMergeTest

/// Verifies PWUtils now inherits directly from PWUtilsCommon (PWUtilsMobile layer removed).
- (void)testPWUtilsInheritsDirectlyFromPWUtilsCommon {
    XCTAssertEqualObjects([PWUtils superclass], NSClassFromString(@"PWUtilsCommon"));
    XCTAssertNil(NSClassFromString(@"PWUtilsMobile"));
}

/// Verifies getAPSProductionStatus: still resolves on PWUtils and returns NO on the simulator.
- (void)testGetAPSProductionStatusReturnsNoOnSimulator {
    XCTAssertFalse([PWUtils getAPSProductionStatus:NO]);
}

/// Verifies reachability still resolves on PWUtils and returns a non-nil object.
- (void)testReachabilityResolvesAndReturnsObject {
    XCTAssertTrue([PWUtils respondsToSelector:@selector(reachability)]);
    id reachability = [PWUtils performSelector:@selector(reachability)];
    XCTAssertNotNil(reachability);
}

/// Verifies the REAL background-task method (not the old nil stub) is used: start returns a non-nil task id.
- (void)testStartBackgroundTaskUsesRealImplementation {
    NSNumber *taskId = [PWUtils startBackgroundTask];
    XCTAssertNotNil(taskId);
    [PWUtils stopBackgroundTask:taskId];
}

/// Verifies stopBackgroundTask: tolerates a nil task id without raising.
- (void)testStopBackgroundTaskWithNilDoesNotRaise {
    XCTAssertNoThrow([PWUtils stopBackgroundTask:nil]);
}

@end
