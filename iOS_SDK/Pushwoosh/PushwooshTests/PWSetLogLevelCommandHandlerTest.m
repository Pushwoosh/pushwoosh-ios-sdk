#import <XCTest/XCTest.h>

#import "PWSetLogLevelCommandHandler.h"
#import "PWPreferences.h"
#import "PushwooshLog.h"

@interface PWSetLogLevelCommandHandlerTest : XCTestCase

@property (nonatomic, strong) PWSetLogLevelCommandHandler *handler;
@property (nonatomic) unsigned int originalLogLevel;

@end

@implementation PWSetLogLevelCommandHandlerTest

- (void)setUp {
    [super setUp];
    _handler = [[PWSetLogLevelCommandHandler alloc] init];
    _originalLogLevel = [PWPreferences preferences].logLevel;
}

- (void)tearDown {
    [PWPreferences preferences].logLevel = _originalLogLevel;
    [super tearDown];
}

#pragma mark - commandName

/// Verifies that commandName is exactly "setLogLevel" so it routes from PWSystemCommandDispatcher correctly.
- (void)testCommandName_isSetLogLevel {
    XCTAssertEqualObjects(_handler.commandName, @"setLogLevel");
}

#pragma mark - handleCommand level mapping

/// Verifies that value="INFO" persists PW_LL_INFO into PWPreferences.logLevel and returns YES.
- (void)testHandleCommand_info_setsInfoLevel {
    BOOL result = [_handler handleCommand:@{@"value": @"INFO"}];

    XCTAssertTrue(result);
    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_INFO);
}

/// Verifies that value="DEBUG" persists PW_LL_DEBUG into PWPreferences.logLevel.
- (void)testHandleCommand_debug_setsDebugLevel {
    XCTAssertTrue([_handler handleCommand:@{@"value": @"DEBUG"}]);

    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_DEBUG);
}

/// Verifies that value="NONE" persists PW_LL_NONE (disables logging entirely).
- (void)testHandleCommand_none_setsNoneLevel {
    XCTAssertTrue([_handler handleCommand:@{@"value": @"NONE"}]);

    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_NONE);
}

/// Verifies that value="ERROR" persists PW_LL_ERROR.
- (void)testHandleCommand_error_setsErrorLevel {
    XCTAssertTrue([_handler handleCommand:@{@"value": @"ERROR"}]);

    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_ERROR);
}

/// Verifies that value="WARN" and value="WARNING" both map to PW_LL_WARN (synonym handling).
- (void)testHandleCommand_warnAndWarning_bothMapToWarn {
    XCTAssertTrue([_handler handleCommand:@{@"value": @"WARN"}]);
    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_WARN);

    [PWPreferences preferences].logLevel = (unsigned int)PW_LL_NONE;
    XCTAssertTrue([_handler handleCommand:@{@"value": @"WARNING"}]);
    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_WARN);
}

/// Verifies that value="VERBOSE" persists PW_LL_VERBOSE.
- (void)testHandleCommand_verbose_setsVerboseLevel {
    XCTAssertTrue([_handler handleCommand:@{@"value": @"VERBOSE"}]);

    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_VERBOSE);
}

/// Verifies that lowercase value="debug" is treated case-insensitively and still maps to PW_LL_DEBUG.
- (void)testHandleCommand_lowercaseLevel_isCaseInsensitive {
    XCTAssertTrue([_handler handleCommand:@{@"value": @"debug"}]);

    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_DEBUG);
}

/// Verifies that mixed case value="DeBuG" still maps to PW_LL_DEBUG.
- (void)testHandleCommand_mixedCaseLevel_isCaseInsensitive {
    XCTAssertTrue([_handler handleCommand:@{@"value": @"DeBuG"}]);

    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_DEBUG);
}

#pragma mark - handleCommand fallbacks

/// Verifies that an unknown level string falls back to PW_LL_INFO and the command still reports success.
- (void)testHandleCommand_unknownLevel_defaultsToInfoAndReturnsYes {
    BOOL result = [_handler handleCommand:@{@"value": @"NUCLEAR"}];

    XCTAssertTrue(result);
    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_INFO);
}

#pragma mark - handleCommand validation

/// Verifies that missing "value" key returns NO and does NOT mutate PWPreferences.logLevel.
- (void)testHandleCommand_missingValue_returnsNoAndPreservesLevel {
    [PWPreferences preferences].logLevel = (unsigned int)PW_LL_DEBUG;

    BOOL result = [_handler handleCommand:@{}];

    XCTAssertFalse(result);
    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_DEBUG);
}

/// Verifies that a non-NSString "value" (e.g. NSNumber) returns NO and does NOT mutate PWPreferences.logLevel.
- (void)testHandleCommand_nonStringValue_returnsNoAndPreservesLevel {
    [PWPreferences preferences].logLevel = (unsigned int)PW_LL_DEBUG;

    BOOL result = [_handler handleCommand:@{@"value": @42}];

    XCTAssertFalse(result);
    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_DEBUG);
}

/// Verifies that NSNull as value is rejected (returns NO) and PWPreferences.logLevel stays unchanged.
- (void)testHandleCommand_nsnullValue_returnsNoAndPreservesLevel {
    [PWPreferences preferences].logLevel = (unsigned int)PW_LL_DEBUG;

    BOOL result = [_handler handleCommand:@{@"value": [NSNull null]}];

    XCTAssertFalse(result);
    XCTAssertEqual([PWPreferences preferences].logLevel, (unsigned int)PW_LL_DEBUG);
}

@end
