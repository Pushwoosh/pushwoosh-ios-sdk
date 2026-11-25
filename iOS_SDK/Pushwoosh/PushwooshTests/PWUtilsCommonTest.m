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

/// Verifies that preferredLocale returns the device's first preferred language whole, region included.
- (void)testPreferredLocaleReturnsFullTagFromPreferredLanguages {
    id localeMock = OCMClassMock([NSLocale class]);
    OCMStub([localeMock preferredLanguages]).andReturn((@[ @"pt-BR", @"en" ]));

    XCTAssertEqualObjects([PWUtils preferredLocale], @"pt-BR");

    [localeMock stopMocking];
}

/// Verifies that a device reporting no preferred language yields nil rather than a placeholder string.
- (void)testPreferredLocaleIsNilWhenDeviceReportsNoLanguages {
    id localeMock = OCMClassMock([NSLocale class]);
    OCMStub([localeMock preferredLanguages]).andReturn(@[]);

    XCTAssertNil([PWUtils preferredLocale]);

    [localeMock stopMocking];
}

/// Verifies that preferredLocale does not shorten a script-and-region tag the way preferredLanguage does.
- (void)testPreferredLocaleKeepsScriptAndRegion {
    id localeMock = OCMClassMock([NSLocale class]);
    OCMStub([localeMock preferredLanguages]).andReturn(@[ @"zh-Hant-TW" ]);

    XCTAssertEqualObjects([PWUtils preferredLocale], @"zh-Hant-TW");

    [localeMock stopMocking];
}

/// Verifies that machineName returns a real, non-empty hardware identifier (e.g. "arm64", "iPhone16,1").
- (void)testMachineNameReturnsNonEmpty {
    NSString *machine = [PWUtils machineName];

    XCTAssertNotNil(machine);
    XCTAssertGreaterThan(machine.length, 0);
}

- (NSString *)timezoneWithLocalTimeZone:(NSTimeZone *)timeZone {
    id timeZoneMock = OCMClassMock([NSTimeZone class]);
    OCMStub(ClassMethod([timeZoneMock localTimeZone])).andReturn(timeZone);
    NSString *value = [PWUtils timezone];
    [timeZoneMock stopMocking];
    return value;
}

/// Verifies that timezone returns the IANA name of the device time zone.
- (void)testTimezoneReturnsZoneName {
    XCTAssertEqualObjects([self timezoneWithLocalTimeZone:[NSTimeZone timeZoneWithName:@"Europe/Paris"]], @"Europe/Paris");
}

/// Verifies that a zone defined only by a GMT offset is sent as the offset in seconds, as before.
- (void)testTimezoneReturnsSecondsForOffsetZone {
    XCTAssertEqualObjects([self timezoneWithLocalTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:10800]], @"10800");
    XCTAssertEqualObjects([self timezoneWithLocalTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:-18000]], @"-18000");
}

/// Verifies that GMT and Etc/GMT zones are sent by name.
- (void)testTimezoneReturnsGMTAndEtcNames {
    XCTAssertEqualObjects([self timezoneWithLocalTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]], @"GMT");
    XCTAssertEqualObjects([self timezoneWithLocalTimeZone:[NSTimeZone timeZoneWithName:@"Etc/GMT-3"]], @"Etc/GMT-3");
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
