#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWResource.h"
#import "PWCache.h"
#import "PWConfig.h"

/// iOS half of the cross-platform placeholder matrix: every placeholder form the Pushwoosh editor can
/// generate, pinned on the output the SDK produces today. The Android half, row for row identical in
/// inputs, is PlaceholderSubstitutorParityTest.java. Group E holds the four forms whose output already
/// differs between the platforms on master; they are recorded, not fixed.
@interface PWResourcePlaceholderParityTest : XCTestCase

@property (nonatomic, strong) PWResource *resource;
@property (nonatomic, strong) id cacheMock;
@property (nonatomic, strong) id configMock;

@end

@implementation PWResourcePlaceholderParityTest

- (void)setUp {
    [super setUp];
    self.resource = [[PWResource alloc] initWithDictionary:@{ @"code": @"TEST-PARITY",
                                                              @"url": @"https://example.com/test.zip",
                                                              @"updated": @1 }];
    [[NSFileManager defaultManager] createDirectoryAtPath:[self.resource localPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    [self stubTags:nil];
    self.configMock = OCMPartialMock([PWConfig config]);
    OCMStub([self.configMock allowCollectingDeviceModel]).andReturn(NO);
    OCMStub([self.configMock allowCollectingDeviceOsVersion]).andReturn(NO);
}

- (void)tearDown {
    /// PWCache and PWConfig are singletons, so a partial mock left standing would leak into every later suite.
    [self.cacheMock stopMocking];
    self.cacheMock = nil;
    [self.configMock stopMocking];
    self.configMock = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[self.resource localPath] error:nil];
    self.resource = nil;
    [super tearDown];
}

- (void)stubTags:(NSDictionary *)tags {
    [self.cacheMock stopMocking];
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(tags);
}

- (void)writePushwooshConfig:(NSString *)json {
    [json writeToFile:[self.resource configUrl] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self.resource readConfig];
}

- (void)assertContent:(NSString *)input becomes:(NSString *)expected {
    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected, @"input %@", input);
}

#pragma mark - Group A: key and tag absent

/// Verifies the seven editor-generated placeholder shapes resolve to their defaults when no key and no tag exist.
- (void)testGroupAKeyAndTagAbsentResolveToDefaults {
    [self assertContent:@"{{Promo|text|Save}}" becomes:@"Save"];
    [self assertContent:@"{{Promo|text}}" becomes:@"Promo"];
    [self assertContent:@"{{Promo|color|#ffffff}}" becomes:@"#ffffff"];
    [self assertContent:@"{{Promo|html|<b>x</b>}}" becomes:@"<b>x</b>"];
    [self assertContent:@"{Promo|text|Save}" becomes:@"Save"];
    [self assertContent:@"{Promo|text|}" becomes:@""];
    [self assertContent:@"{Promo Code|text|Save}" becomes:@"Save"];
}

#pragma mark - Group B: modifier sweep against an absent tag

/// Verifies that none of the 18 SDK modifiers, nor the platform-generated "regular", alters a digit-only
/// default or turns an empty default into anything but the empty string.
- (void)testGroupBModifierSweepLeavesDigitOnlyDefaultAlone {
    NSArray<NSString *> *modifiers = @[ @"lowercase", @"UPPERCASE", @"CapitalizeFirst", @"CapitalizeAllFirst",
                                        @"cent", @"dollar", @"comma", @"euro", @"jpy", @"lira",
                                        @"M-d-y", @"m-d-y", @"M d y", @"M d Y", @"l", @"M d", @"H:i",
                                        @"m-d-y H:i", @"regular" ];

    for (NSString *modifier in modifiers) {
        [self assertContent:[NSString stringWithFormat:@"{Promo|%@|7}", modifier] becomes:@"7"];
        [self assertContent:[NSString stringWithFormat:@"{Promo|%@|}", modifier] becomes:@""];
    }
}

#pragma mark - Group C: modifier applied to a present tag

/// Verifies that UPPERCASE is applied to the value of a tag that exists.
- (void)testGroupCUppercaseModifierOnPresentTag {
    [self stubTags:@{ @"Name": @"aLICE bob" }];

    [self assertContent:@"{Name|UPPERCASE|d}" becomes:@"ALICE BOB"];
}

/// Verifies that lowercase is applied to the value of a tag that exists.
- (void)testGroupCLowercaseModifierOnPresentTag {
    [self stubTags:@{ @"Name": @"aLICE bob" }];

    [self assertContent:@"{Name|lowercase|d}" becomes:@"alice bob"];
}

#pragma mark - Group D: localization

/// Verifies that a localized value spanning several lines is substituted whole.
- (void)testGroupDMultilineLocalizedValue {
    [self writePushwooshConfig:@"{\"default_language\":\"en\",\"localization\":{\"en\":{\"Welcome\":\"Line1\\nLine2\"}}}"];

    [self assertContent:@"{{Welcome|text|def}}" becomes:@"Line1\nLine2"];
}

/// Verifies that a multiline default survives when the localization key is missing.
- (void)testGroupDMultilineDefaultWithoutLocalizationKey {
    [self writePushwooshConfig:@"{\"default_language\":\"en\",\"localization\":{\"en\":{}}}"];

    [self assertContent:@"{{Welcome|text|multi\nline\ndefault}}" becomes:@"multi\nline\ndefault"];
}

/// Verifies pass ordering: a localized value that itself contains a single-brace tag is collapsed to that tag's default.
- (void)testGroupDLocalizedValueContainingTagCollapsesToItsDefault {
    [self writePushwooshConfig:@"{\"default_language\":\"en\",\"localization\":{\"en\":{\"Welcome\":\"Hi {Name|text|friend}!\"}}}"];

    [self assertContent:@"{{Welcome|text|def}}" becomes:@"Hi friend!"];
}

#pragma mark - Group E: known platform divergences

/// Verifies that an empty double-brace default yields the empty string. Android yields the key name
/// "Promo" instead, because its three-group default ".[^}]*?" needs at least one character and the
/// two-group pass wins. Pre-existing on master; recorded, not fixed.
- (void)testEmptyDoubleBraceDefault_platformDivergenceD1 {
    [self assertContent:@"{{Promo|text|}}" becomes:@""];
}

/// Verifies that a case modifier is applied to the default of an absent tag. Android leaves "save"
/// untouched, because it applies modifiers only when the key is present. Pre-existing on master;
/// recorded, not fixed.
- (void)testCaseModifierOnAbsentTagDefault_platformDivergenceD2 {
    [self assertContent:@"{Promo|UPPERCASE|save}" becomes:@"SAVE"];
}

/// Verifies that a single-character key is a valid placeholder. Android leaves "{X|type|Fb}" verbatim,
/// because its key group ".[^}]+?" requires at least two characters. Pre-existing on master;
/// recorded, not fixed.
- (void)testSingleCharacterKey_platformDivergenceD3 {
    [self assertContent:@"{X|type|Fb}" becomes:@"Fb"];
}

/// Verifies that the one-character date modifier "l" is a valid placeholder modifier. Android leaves
/// "{Promo|l|7}" verbatim, because its modifier group ".[^}]+?" requires at least two characters, so the
/// whole form never matches there. Group B's modifier sweep asserts the same iOS value in passing; this
/// row is where the divergence is named. Pre-existing on master; recorded, not fixed.
- (void)testSingleCharacterModifier_platformDivergenceD4 {
    [self assertContent:@"{Promo|l|7}" becomes:@"7"];
    [self assertContent:@"{Promo|l|}" becomes:@""];
}

@end
