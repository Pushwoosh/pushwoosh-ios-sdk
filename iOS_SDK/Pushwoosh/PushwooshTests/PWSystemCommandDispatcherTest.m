#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWSystemCommandDispatcher.h"
#import "PWSystemCommandHandler.h"

/// Spy handler that records each handleCommand: invocation.
@interface PWSCDSpyHandler : NSObject <PWSystemCommandHandler>

@property (nonatomic, copy) NSString *commandNameValue;
@property (nonatomic) NSUInteger handleCount;
@property (nonatomic, copy) NSDictionary *lastUserInfo;
@property (nonatomic) BOOL returnValue;

@end

@implementation PWSCDSpyHandler

@synthesize commandNameValue = _commandNameValue;

- (instancetype)initWithCommandName:(NSString *)name {
    self = [super init];
    if (self) {
        _commandNameValue = [name copy];
        _returnValue = YES;
    }
    return self;
}

- (NSString *)commandName {
    return _commandNameValue;
}

- (BOOL)handleCommand:(NSDictionary *)userInfo {
    _handleCount++;
    _lastUserInfo = [userInfo copy];
    return _returnValue;
}

@end

@interface PWSystemCommandDispatcherTest : XCTestCase

@property (nonatomic, strong) PWSystemCommandDispatcher *dispatcher;

@end

@implementation PWSystemCommandDispatcherTest

- (void)setUp {
    [super setUp];
    _dispatcher = [[PWSystemCommandDispatcher alloc] init];
}

#pragma mark - Singleton

/// Verifies that shared returns the same singleton instance across calls.
- (void)testSharedIsSingleton {
    PWSystemCommandDispatcher *a = [PWSystemCommandDispatcher shared];
    PWSystemCommandDispatcher *b = [PWSystemCommandDispatcher shared];

    XCTAssertNotNil(a);
    XCTAssertEqual(a, b);
}

#pragma mark - isSystemPush gating

/// Verifies that processUserInfo returns NO when userInfo is nil.
- (void)testProcessUserInfo_nil_returnsNo {
    XCTAssertFalse([_dispatcher processUserInfo:nil]);
}

/// Verifies that processUserInfo returns NO when pw_system_push key is absent.
- (void)testProcessUserInfo_noSystemPushKey_returnsNo {
    NSDictionary *userInfo = @{@"aps": @{}, @"pw_command": @"setLogLevel"};
    XCTAssertFalse([_dispatcher processUserInfo:userInfo]);
}

/// Verifies that processUserInfo returns NO when pw_system_push is 0 (NSNumber).
- (void)testProcessUserInfo_systemPushZero_returnsNo {
    NSDictionary *userInfo = @{@"pw_system_push": @0, @"pw_command": @"setLogLevel"};
    XCTAssertFalse([_dispatcher processUserInfo:userInfo]);
}

/// Verifies that processUserInfo treats pw_system_push="1" (NSString) the same as pw_system_push=1 (NSNumber).
- (void)testProcessUserInfo_systemPushStringOne_isAccepted {
    PWSCDSpyHandler *spy = [[PWSCDSpyHandler alloc] initWithCommandName:@"cmd1"];
    [_dispatcher registerHandler:spy];

    BOOL handled = [_dispatcher processUserInfo:@{@"pw_system_push": @"1", @"pw_command": @"cmd1"}];

    XCTAssertTrue(handled);
    XCTAssertEqual(spy.handleCount, 1u);
}

/// Verifies that processUserInfo returns YES (system push acknowledged) even when pw_command is missing — no handler is invoked.
- (void)testProcessUserInfo_systemPushButMissingCommand_returnsYesAndDoesNotInvokeHandler {
    PWSCDSpyHandler *spy = [[PWSCDSpyHandler alloc] initWithCommandName:@"cmd1"];
    [_dispatcher registerHandler:spy];

    BOOL handled = [_dispatcher processUserInfo:@{@"pw_system_push": @1}];

    XCTAssertTrue(handled);
    XCTAssertEqual(spy.handleCount, 0u);
}

#pragma mark - Single command (old format)

/// Verifies that pw_command + value reaches the matching handler with both keys in the forwarded userInfo.
- (void)testProcessUserInfo_singleCommand_forwardsCommandAndValueToHandler {
    PWSCDSpyHandler *spy = [[PWSCDSpyHandler alloc] initWithCommandName:@"setLogLevel"];
    [_dispatcher registerHandler:spy];

    BOOL handled = [_dispatcher processUserInfo:@{
        @"pw_system_push": @1,
        @"pw_command": @"setLogLevel",
        @"value": @"DEBUG"
    }];

    XCTAssertTrue(handled);
    XCTAssertEqual(spy.handleCount, 1u);
    XCTAssertEqualObjects(spy.lastUserInfo[@"pw_command"], @"setLogLevel");
    XCTAssertEqualObjects(spy.lastUserInfo[@"value"], @"DEBUG");
}

/// Verifies that a command without a matching registered handler returns YES (system push acknowledged) but invokes nothing.
- (void)testProcessUserInfo_singleCommand_noHandler_returnsYesAndInvokesNothing {
    PWSCDSpyHandler *spy = [[PWSCDSpyHandler alloc] initWithCommandName:@"setLogLevel"];
    [_dispatcher registerHandler:spy];

    BOOL handled = [_dispatcher processUserInfo:@{
        @"pw_system_push": @1,
        @"pw_command": @"unknownCommand",
        @"value": @"foo"
    }];

    XCTAssertTrue(handled);
    XCTAssertEqual(spy.handleCount, 0u);
}

#pragma mark - Multiple commands (new format)

/// Verifies that pw_commands array dispatches each command in order to its handler.
- (void)testProcessUserInfo_pwCommandsArray_dispatchesEachCommand {
    PWSCDSpyHandler *spyA = [[PWSCDSpyHandler alloc] initWithCommandName:@"cmdA"];
    PWSCDSpyHandler *spyB = [[PWSCDSpyHandler alloc] initWithCommandName:@"cmdB"];
    [_dispatcher registerHandler:spyA];
    [_dispatcher registerHandler:spyB];

    BOOL handled = [_dispatcher processUserInfo:@{
        @"pw_system_push": @1,
        @"pw_commands": @[
            @{@"command": @"cmdA", @"value": @"a-val"},
            @{@"command": @"cmdB", @"value": @"b-val"},
        ],
    }];

    XCTAssertTrue(handled);
    XCTAssertEqual(spyA.handleCount, 1u);
    XCTAssertEqualObjects(spyA.lastUserInfo[@"value"], @"a-val");
    XCTAssertEqual(spyB.handleCount, 1u);
    XCTAssertEqualObjects(spyB.lastUserInfo[@"value"], @"b-val");
}

/// Verifies that non-dictionary items inside pw_commands array are silently skipped.
- (void)testProcessUserInfo_pwCommandsArray_skipsNonDictItems {
    PWSCDSpyHandler *spy = [[PWSCDSpyHandler alloc] initWithCommandName:@"cmdA"];
    [_dispatcher registerHandler:spy];

    BOOL handled = [_dispatcher processUserInfo:@{
        @"pw_system_push": @1,
        @"pw_commands": @[
            @"not-a-dict",
            @42,
            @{@"command": @"cmdA", @"value": @"only-this-counts"},
        ],
    }];

    XCTAssertTrue(handled);
    XCTAssertEqual(spy.handleCount, 1u);
    XCTAssertEqualObjects(spy.lastUserInfo[@"value"], @"only-this-counts");
}

/// Verifies that pw_commands with empty/non-string "command" field is skipped silently.
- (void)testProcessUserInfo_pwCommandsArray_skipsEntriesWithMissingCommandName {
    PWSCDSpyHandler *spy = [[PWSCDSpyHandler alloc] initWithCommandName:@"cmdA"];
    [_dispatcher registerHandler:spy];

    BOOL handled = [_dispatcher processUserInfo:@{
        @"pw_system_push": @1,
        @"pw_commands": @[
            @{@"value": @"orphaned"},
            @{@"command": @42, @"value": @"non-string-command"},
            @{@"command": @"cmdA", @"value": @"valid"},
        ],
    }];

    XCTAssertTrue(handled);
    XCTAssertEqual(spy.handleCount, 1u);
    XCTAssertEqualObjects(spy.lastUserInfo[@"value"], @"valid");
}

#pragma mark - registerHandler / unregisterHandlerForCommand

/// Verifies that registering a second handler with the same commandName replaces the first.
- (void)testRegisterHandler_sameCommandName_replacesExisting {
    PWSCDSpyHandler *first = [[PWSCDSpyHandler alloc] initWithCommandName:@"dup"];
    PWSCDSpyHandler *second = [[PWSCDSpyHandler alloc] initWithCommandName:@"dup"];
    [_dispatcher registerHandler:first];
    [_dispatcher registerHandler:second];

    [_dispatcher processUserInfo:@{@"pw_system_push": @1, @"pw_command": @"dup"}];

    XCTAssertEqual(first.handleCount, 0u);
    XCTAssertEqual(second.handleCount, 1u);
}

/// Verifies that registerHandler:nil is a safe no-op (no crash, no state change).
- (void)testRegisterHandler_nil_isSafeNoOp {
    XCTAssertNoThrow([_dispatcher registerHandler:nil]);
}

/// Verifies that registering a handler with nil commandName is rejected.
- (void)testRegisterHandler_nilCommandName_isRejected {
    PWSCDSpyHandler *bad = [[PWSCDSpyHandler alloc] initWithCommandName:nil];

    XCTAssertNoThrow([_dispatcher registerHandler:bad]);

    [_dispatcher processUserInfo:@{@"pw_system_push": @1, @"pw_command": @"anything"}];
    XCTAssertEqual(bad.handleCount, 0u);
}

/// Verifies that unregisterHandlerForCommand removes the handler so subsequent commands of that name invoke nothing.
- (void)testUnregisterHandlerForCommand_removesHandler {
    PWSCDSpyHandler *spy = [[PWSCDSpyHandler alloc] initWithCommandName:@"cmd"];
    [_dispatcher registerHandler:spy];

    [_dispatcher unregisterHandlerForCommand:@"cmd"];

    [_dispatcher processUserInfo:@{@"pw_system_push": @1, @"pw_command": @"cmd"}];
    XCTAssertEqual(spy.handleCount, 0u);
}

/// Verifies that unregisterHandlerForCommand:nil is a safe no-op.
- (void)testUnregisterHandlerForCommand_nil_isSafeNoOp {
    XCTAssertNoThrow([_dispatcher unregisterHandlerForCommand:nil]);
}

#pragma mark - Built-in handlers

/// Verifies that a freshly initialized dispatcher already has built-in handlers (setLogLevel, set_base_url) registered.
- (void)testInit_registersBuiltInHandlers {
    BOOL setLogLevelHandled = [_dispatcher processUserInfo:@{
        @"pw_system_push": @1,
        @"pw_command": @"setLogLevel",
        @"value": @"INFO"
    }];
    BOOL setBaseUrlHandled = [_dispatcher processUserInfo:@{
        @"pw_system_push": @1,
        @"pw_command": @"set_base_url",
        @"value": @"https://example.com/json/1.3/"
    }];

    XCTAssertTrue(setLogLevelHandled, @"setLogLevel must be a built-in handler");
    XCTAssertTrue(setBaseUrlHandled, @"set_base_url must be a built-in handler");
}

@end
