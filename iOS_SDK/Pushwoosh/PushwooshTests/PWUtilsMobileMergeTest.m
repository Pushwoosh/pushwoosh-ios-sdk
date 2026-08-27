#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UIKit/UIKit.h>

#import "PWUtils.h"

@interface PWUtils (OpenOutcomeTest)

+ (void)openURLReportingOutcome:(NSURL *)url;

@end

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

- (id)applicationMockCompletingWith:(BOOL)success {
    id applicationMock = OCMClassMock([UIApplication class]);
    OCMStub([applicationMock sharedApplication]).andReturn(applicationMock);
    OCMStub([applicationMock openURL:[OCMArg any] options:[OCMArg any] completionHandler:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained void (^completion)(BOOL) = nil;
        [invocation getArgument:&completion atIndex:4];
        if (completion) {
            completion(success);
        }
    });
    return applicationMock;
}

/// Verifies that a failed open is reported as an error carrying the Android-identical prefix and a redacted URL.
- (void)testOpenURLReportingOutcomeLogsErrorWhenOpenFails {
    id applicationMock = [self applicationMockCompletingWith:NO];
    id logMock = OCMClassMock([PushwooshLog class]);

    [PWUtils openURLReportingOutcome:[NSURL URLWithString:@"tel:12345"]];

    OCMVerify([logMock pushwooshLog:PW_LL_ERROR className:[OCMArg any] message:@"Can't open remote url: tel:"]);
    [logMock stopMocking];
    [applicationMock stopMocking];
}

/// Verifies that a successful open is reported at debug level, also with a redacted URL.
- (void)testOpenURLReportingOutcomeLogsDebugWhenOpenSucceeds {
    id applicationMock = [self applicationMockCompletingWith:YES];
    id logMock = OCMClassMock([PushwooshLog class]);

    [PWUtils openURLReportingOutcome:[NSURL URLWithString:@"myapp://deal?token=secret"]];

    OCMVerify([logMock pushwooshLog:PW_LL_DEBUG className:[OCMArg any] message:@"Opened remote url: myapp://deal"]);
    [logMock stopMocking];
    [applicationMock stopMocking];
}

/// Verifies that the Safari fallback reports its outcome through the same helper.
- (void)testOpenURLInSafariReportsOutcome {
    id applicationMock = [self applicationMockCompletingWith:NO];
    id logMock = OCMClassMock([PushwooshLog class]);

    [PWUtils performSelector:@selector(openURLInSafari:) withObject:[NSURL URLWithString:@"https://Example.COM/promo?token=secret"]];

    OCMVerify([logMock pushwooshLog:PW_LL_ERROR className:[OCMArg any] message:@"Can't open remote url: https://example.com"]);
    [logMock stopMocking];
    [applicationMock stopMocking];
}

@end
