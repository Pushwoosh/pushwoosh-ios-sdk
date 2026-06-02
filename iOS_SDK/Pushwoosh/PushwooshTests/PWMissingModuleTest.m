
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWMissingModule.h"
#import "PushwooshLog.h"

@protocol PWMissingModuleTestProto <NSObject>
+ (BOOL)isEnabled;
+ (NSString *)getPersistentHWID;
+ (void)doSomething;
+ (NSInteger)currentEnvironment;
+ (BOOL)handleTVOSPushWithUserInfo:(NSDictionary *)info;
+ (void)startLiveActivityWithToken:(NSString *)token
                        activityId:(NSString *)activityId
                        completion:(void (^)(NSError *))completion;
+ (void)stopLiveActivityWithCompletion:(void (^)(NSError *))completion;
+ (void)configureCloseButton:(BOOL)show;
+ (void)setIncomingCallTimeout:(NSTimeInterval)timeout;
+ (void)configureRichMediaWithPosition:(NSInteger)position
                       presentAnimation:(NSInteger)present
                       dismissAnimation:(NSInteger)dismiss;
+ (void)setDidTapForegroundPush:(void (^)(NSDictionary *))handler;
@end

@interface PWMissingModuleTest : XCTestCase
@end

@implementation PWMissingModuleTest

- (void)setUp {
    [super setUp];
    [PWMissingModule _resetLogStateForTesting];
}

- (void)tearDown {
    [PWMissingModule _resetLogStateForTesting];
    [super tearDown];
}

/// Verifies that respondsToSelector: returns YES for an arbitrary selector.
- (void)testRespondsToSelectorAlwaysYES {
    XCTAssertTrue([PWMissingModule respondsToSelector:@selector(doSomething)]);
    XCTAssertTrue([PWMissingModule respondsToSelector:@selector(getPersistentHWID)]);
    XCTAssertTrue([PWMissingModule respondsToSelector:NSSelectorFromString(@"arbitraryUnknownSelector")]);
}

/// Verifies that a void selector does not crash when forwarded.
- (void)testVoidSelectorDoesNotCrash {
    XCTAssertNoThrow([(Class<PWMissingModuleTestProto>)[PWMissingModule class] doSomething]);
}

/// Verifies that a BOOL-returning selector returns NO via zeroed return value.
- (void)testBoolReturnReturnsNO {
    BOOL result = [(Class<PWMissingModuleTestProto>)[PWMissingModule class] isEnabled];

    XCTAssertFalse(result);
}

/// Verifies that an object-returning selector returns nil via zeroed return value.
- (void)testObjectReturnReturnsNil {
    NSString *result = [(Class<PWMissingModuleTestProto>)[PWMissingModule class] getPersistentHWID];

    XCTAssertNil(result);
}

/// Verifies that an integer-returning selector returns 0 via zeroed return value.
- (void)testIntegerReturnReturnsZero {
    NSInteger result = [(Class<PWMissingModuleTestProto>)[PWMissingModule class] currentEnvironment];

    XCTAssertEqual(result, 0);
}

/// Verifies that forwardInvocation: logs through PushwooshLog at PW_LL_INFO.
- (void)testForwardInvocationLogsThroughPushwooshLog {
    id logMock = OCMClassMock([PushwooshLog class]);
    SEL knownSelector = @selector(doSomething);

    OCMExpect([logMock pushwooshLog:PW_LL_INFO className:[PWMissingModule class] message:[OCMArg checkWithBlock:^BOOL(NSString *msg) {
        return [msg containsString:NSStringFromSelector(knownSelector)];
    }]]);

    [(Class<PWMissingModuleTestProto>)[PWMissingModule class] doSomething];

    OCMVerifyAll(logMock);
    [logMock stopMocking];
}

/// Verifies that subsequent calls with the same selector do not log again.
- (void)testForwardInvocationLogsOnce {
    SEL knownSelector = @selector(doSomething);
    [(Class<PWMissingModuleTestProto>)[PWMissingModule class] doSomething];

    id logMock = OCMClassMock([PushwooshLog class]);
    OCMReject([logMock pushwooshLog:PW_LL_INFO className:OCMOCK_ANY message:[OCMArg checkWithBlock:^BOOL(NSString *msg) {
        return [msg containsString:NSStringFromSelector(knownSelector)];
    }]]);

    [(Class<PWMissingModuleTestProto>)[PWMissingModule class] doSomething];
    [(Class<PWMissingModuleTestProto>)[PWMissingModule class] doSomething];

    OCMVerifyAll(logMock);
    [logMock stopMocking];
}

/// Verifies that handleTVOSPushWithUserInfo: returns NO instead of garbage when module is missing.
- (void)testHandleTVOSPushReturnsNOForMissingModule {
    NSDictionary *info = @{@"aps": @{@"alert": @"hi"}};

    BOOL result = [(Class<PWMissingModuleTestProto>)[PWMissingModule class] handleTVOSPushWithUserInfo:info];

    XCTAssertFalse(result);
}

/// Verifies that a completion-block selector forwards the block with a "module not linked" NSError.
- (void)testCompletionBlockInvokedWithErrorForMissingModule {
    __block BOOL blockInvoked = NO;
    __block NSError *capturedError = nil;
    void (^completion)(NSError *) = ^(NSError *error) {
        blockInvoked = YES;
        capturedError = error;
    };

    XCTAssertNoThrow([(Class<PWMissingModuleTestProto>)[PWMissingModule class]
                      startLiveActivityWithToken:@"abc"
                                      activityId:@"act-1"
                                      completion:completion]);

    XCTAssertTrue(blockInvoked);
    XCTAssertNotNil(capturedError);
    XCTAssertEqualObjects(capturedError.domain, @"com.pushwoosh.module");
    XCTAssertEqual(capturedError.code, -1);
    XCTAssertTrue([capturedError.localizedDescription containsString:@"not linked"]);
}

/// Verifies that a single-arg completion-block selector also invokes the block with NSError.
- (void)testStopLiveActivityWithCompletionInvokesBlockWithError {
    __block BOOL blockInvoked = NO;
    __block NSError *capturedError = nil;
    void (^completion)(NSError *) = ^(NSError *error) {
        blockInvoked = YES;
        capturedError = error;
    };

    XCTAssertNoThrow([(Class<PWMissingModuleTestProto>)[PWMissingModule class]
                      stopLiveActivityWithCompletion:completion]);

    XCTAssertTrue(blockInvoked);
    XCTAssertNotNil(capturedError);
}

/// Verifies that nil completion blocks do not crash when forwarded through PWMissingModule.
- (void)testNilCompletionBlockDoesNotCrash {
    XCTAssertNoThrow([(Class<PWMissingModuleTestProto>)[PWMissingModule class]
                      stopLiveActivityWithCompletion:nil]);
    XCTAssertNoThrow([(Class<PWMissingModuleTestProto>)[PWMissingModule class]
                      startLiveActivityWithToken:@"abc"
                                      activityId:@"act-1"
                                      completion:nil]);
}

/// Verifies that a non-completion selector that takes a block stores it (does NOT invoke it).
/// `setDidTapForegroundPush:` is the canonical case — clients pass a closure that
/// must be retained and called later, not invoked synchronously at registration.
- (void)testNonCompletionBlockArgumentIsNotInvoked {
    __block BOOL blockInvoked = NO;
    void (^tapHandler)(NSDictionary *) = ^(NSDictionary *userInfo) {
        blockInvoked = YES;
    };

    XCTAssertNoThrow([(Class<PWMissingModuleTestProto>)[PWMissingModule class]
                      setDidTapForegroundPush:tapHandler]);

    XCTAssertFalse(blockInvoked);
}

/// Verifies that a BOOL-argument primitive setter forwards without crashing.
- (void)testBoolArgumentSelectorDoesNotCrash {
    XCTAssertNoThrow([(Class<PWMissingModuleTestProto>)[PWMissingModule class] configureCloseButton:YES]);
    XCTAssertNoThrow([(Class<PWMissingModuleTestProto>)[PWMissingModule class] configureCloseButton:NO]);
}

/// Verifies that a TimeInterval primitive setter forwards without crashing.
- (void)testTimeIntervalSelectorDoesNotCrash {
    XCTAssertNoThrow([(Class<PWMissingModuleTestProto>)[PWMissingModule class] setIncomingCallTimeout:45.0]);
}

/// Verifies that a multi-enum selector forwards without crashing.
- (void)testMultiEnumSelectorDoesNotCrash {
    XCTAssertNoThrow([(Class<PWMissingModuleTestProto>)[PWMissingModule class]
                      configureRichMediaWithPosition:1
                                    presentAnimation:2
                                    dismissAnimation:3]);
}

/// Verifies that an unknown selector logs a PW_LL_WARN signature warning.
- (void)testUnknownSelectorLogsWarnSignature {
    id logMock = OCMClassMock([PushwooshLog class]);
    SEL unknownSelector = NSSelectorFromString(@"someUnknownBackchannelSelectorXYZ");

    OCMExpect([logMock pushwooshLog:PW_LL_WARN className:[PWMissingModule class] message:[OCMArg checkWithBlock:^BOOL(NSString *msg) {
        return [msg containsString:@"someUnknownBackchannelSelectorXYZ"]
            && [msg containsString:@"knownSignatures"];
    }]]);

    NSMethodSignature *signature = [PWMissingModule methodSignatureForSelector:unknownSelector];
    XCTAssertNotNil(signature);
    XCTAssertEqual(signature.numberOfArguments, 2u);
    XCTAssertEqualObjects([NSString stringWithUTF8String:signature.methodReturnType], @"v");

    OCMVerifyAll(logMock);
    [logMock stopMocking];
}

/// Verifies that the same unknown selector logs WARN only once.
- (void)testUnknownSelectorLogsWarnOnce {
    SEL unknownSelector = NSSelectorFromString(@"yetAnotherUnknownSelectorXYZ");
    (void)[PWMissingModule methodSignatureForSelector:unknownSelector];

    id logMock = OCMClassMock([PushwooshLog class]);
    OCMReject([logMock pushwooshLog:PW_LL_WARN className:OCMOCK_ANY message:[OCMArg checkWithBlock:^BOOL(NSString *msg) {
        return [msg containsString:@"yetAnotherUnknownSelectorXYZ"];
    }]]);

    (void)[PWMissingModule methodSignatureForSelector:unknownSelector];
    (void)[PWMissingModule methodSignatureForSelector:unknownSelector];

    OCMVerifyAll(logMock);
    [logMock stopMocking];
}

/// Verifies that known selectors in the LiveActivities set resolve to a signature without falling through to the WARN log.
- (void)testKnownLiveActivitySelectorResolvesWithoutWarn {
    id logMock = OCMClassMock([PushwooshLog class]);
    OCMReject([logMock pushwooshLog:PW_LL_WARN className:OCMOCK_ANY message:OCMOCK_ANY]);

    NSMethodSignature *signature = [PWMissingModule methodSignatureForSelector:
        NSSelectorFromString(@"startLiveActivityWithToken:activityId:completion:")];

    XCTAssertNotNil(signature);
    XCTAssertEqual(signature.numberOfArguments, 5u);

    OCMVerifyAll(logMock);
    [logMock stopMocking];
}

@end
