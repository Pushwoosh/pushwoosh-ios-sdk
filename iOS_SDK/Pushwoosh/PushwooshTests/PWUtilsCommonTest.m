#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWUtils.h"
#import "PWUtils+Internal.h"

@interface PWUtils (CommonTest)
+ (BOOL)isShortenedUrl:(NSURL *)url;
@end

@interface PWUtilsCommonTest : XCTestCase
@end

@implementation PWUtilsCommonTest

/// Verifies that preferredLanguage returns a real, non-empty language code and never nil.
- (void)testPreferredLanguageReturnsNonEmptyCode {
    NSString *language = [PWUtils preferredLanguage];

    XCTAssertNotNil(language);
    XCTAssertGreaterThan(language.length, 0);
    XCTAssertLessThanOrEqual(language.length, 20);
    XCTAssertFalse([language containsString:@"(null)"]);
}

/// Verifies that machineName returns a real, non-empty hardware identifier (e.g. "arm64", "iPhone16,1").
- (void)testMachineNameReturnsNonEmpty {
    NSString *machine = [PWUtils machineName];

    XCTAssertNotNil(machine);
    XCTAssertGreaterThan(machine.length, 0);
}

/// Verifies that timezone returns a numeric seconds-from-GMT string.
- (void)testTimezoneReturnsNumericString {
    NSString *timezone = [PWUtils timezone];

    XCTAssertNotNil(timezone);
    XCTAssertGreaterThan(timezone.length, 0);

    NSScanner *scanner = [NSScanner scannerWithString:timezone];
    long long seconds = 0;
    XCTAssertTrue([scanner scanLongLong:&seconds]);
    XCTAssertTrue([scanner isAtEnd]);
}

/// Verifies that a custom-scheme URL is passed straight to applicationOpenURL: without a network round-trip.
- (void)testOpenUrlCustomSchemeOpensDirectly {
    id utilsMock = OCMClassMock([PWUtils class]);
    NSURL *url = [NSURL URLWithString:@"myapp://promo"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"applicationOpenURL called"];
    OCMStub([utilsMock applicationOpenURL:url]).andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
    });

    [PWUtils openUrl:url];

    [self waitForExpectations:@[expectation] timeout:2.0];
    [utilsMock stopMocking];
}

/// Verifies that a plain (non-shortened) https URL is passed straight to applicationOpenURL: without resolving over the network.
- (void)testOpenUrlPlainHttpsOpensDirectly {
    id utilsMock = OCMClassMock([PWUtils class]);
    NSURL *url = [NSURL URLWithString:@"https://example.com/page"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"applicationOpenURL called"];
    OCMStub([utilsMock applicationOpenURL:url]).andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
    });

    [PWUtils openUrl:url];

    [self waitForExpectations:@[expectation] timeout:2.0];
    [utilsMock stopMocking];
}

/// Verifies shortened-URL detection: only known shorteners are routed through the network resolver.
- (void)testIsShortenedUrlDetection {
    XCTAssertTrue([PWUtils isShortenedUrl:[NSURL URLWithString:@"http://bit.ly/abc"]]);
    XCTAssertTrue([PWUtils isShortenedUrl:[NSURL URLWithString:@"http://goo.gl/abc"]]);
    XCTAssertFalse([PWUtils isShortenedUrl:[NSURL URLWithString:@"https://example.com/abc"]]);
}

@end
