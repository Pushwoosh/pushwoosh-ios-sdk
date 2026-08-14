
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWResource.h"
#import "PWCache.h"
#import "PWConfig.h"
#import "PWUtils.h"

@interface PWResourceNativeConfigTest : XCTestCase

@property (nonatomic, strong) PWResource *resource;
@property (nonatomic, strong) id cacheMock;
@property (nonatomic, strong) id configMock;

@end

@implementation PWResourceNativeConfigTest

- (void)setUp {
    [super setUp];
    self.resource = [[PWResource alloc] initWithDictionary:@{ @"code": @"TEST-NATIVE-CFG",
                                                              @"url": @"https://example.com/test.zip",
                                                              @"updated": @1 }];
    [[NSFileManager defaultManager] createDirectoryAtPath:[self.resource localPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
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

- (void)writePushwooshConfig:(NSString *)json {
    [json writeToFile:[self.resource configUrl] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

/// Verifies that nativeConfigUrl points to native-config.json inside the unpacked resource folder.
- (void)testNativeConfigUrlIsInsideResourceFolder {
    NSString *expected = [[self.resource localPath] stringByAppendingPathComponent:@"native-config.json"];

    XCTAssertEqualObjects([self.resource nativeConfigUrl], expected);
}

/// Verifies that hasNativeConfig is NO when the resource folder has no native-config.json.
- (void)testHasNativeConfigIsNoWithoutFile {
    XCTAssertFalse([self.resource hasNativeConfig]);
}

/// Verifies that hasNativeConfig becomes YES once native-config.json exists in the resource folder.
- (void)testHasNativeConfigIsYesWithFile {
    [@"{\"displayType\":\"modal\"}" writeToFile:[self.resource nativeConfigUrl]
                                     atomically:YES
                                       encoding:NSUTF8StringEncoding
                                          error:nil];

    XCTAssertTrue([self.resource hasNativeConfig]);
}

/// Verifies that localizeConfig resolves {{key|type|default}} placeholders in nested string values from pushwoosh.json, and falls back to the default for a missing key.
- (void)testLocalizeConfigResolvesPlaceholdersAndDefault {
    [self writePushwooshConfig:@"{\"default_language\":\"en\",\"localization\":{\"en\":{\"greeting\":\"Hello\"}}}"];
    NSDictionary *config = @{ @"modal": @{ @"title": @{ @"text": @"{{greeting|text|Hi}}" },
                                           @"message": @"{{missing|text|Fallback}}" } };

    NSDictionary *localized = [self.resource localizeConfig:config];

    XCTAssertEqualObjects(localized[@"modal"][@"title"][@"text"], @"Hello");
    XCTAssertEqualObjects(localized[@"modal"][@"message"], @"Fallback");
}

/// Verifies that without a pushwoosh.json a plain string is left intact while a placeholder still resolves to its default (parity with the HTML path).
- (void)testLocalizeConfigWithoutLocalizationUsesDefaults {
    NSDictionary *config = @{ @"modal": @{ @"title": @"Plain", @"message": @"{{note|text|Def}}" } };

    NSDictionary *localized = [self.resource localizeConfig:config];

    XCTAssertEqualObjects(localized[@"modal"][@"title"], @"Plain");
    XCTAssertEqualObjects(localized[@"modal"][@"message"], @"Def");
}

/// Verifies the two-step substitution: a {{key}} resolves to a localized string that itself carries a {tag} placeholder, which is then filled from the device tags.
- (void)testLocalizeConfigSubstitutesTagsNestedInLocalizedStrings {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(@{ @"UserName": @"alexey" });
    [@"{\"default_language\":\"default\",\"localization\":{\"default\":{\"t3.text\":\"Button {UserName|CapitalizeAllFirst|пес}\"}}}"
        writeToFile:[self.resource configUrl] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSDictionary *config = @{ @"modal": @{ @"buttons": @[ @{ @"text": @{ @"text": @"{{t3.text|text}}" } } ] } };

    NSDictionary *localized = [self.resource localizeConfig:config];

    XCTAssertEqualObjects(localized[@"modal"][@"buttons"][0][@"text"][@"text"], @"Button Alexey");
}

/// Verifies that an empty payload tag dictionary no longer blocks the cache: the native path never reads payload tags, so the cached value still wins over the placeholder default.
- (void)testLocalizeConfigStillReadsTheCacheWhenThePayloadCarriesAnEmptyTagDictionary {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(@{ @"UserName": @"alexey" });
    PWResource *resource = [[PWResource alloc] initWithDictionary:@{ @"code": @"TEST-NATIVE-CFG",
                                                                     @"url": @"https://example.com/test.zip",
                                                                     @"updated": @1,
                                                                     @"tags": @{} }];
    [@"{\"default_language\":\"default\",\"localization\":{\"default\":{\"t3.text\":\"Button {UserName|CapitalizeAllFirst|пес}\"}}}"
        writeToFile:[resource configUrl] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSDictionary *config = @{ @"modal": @{ @"title": @"{{t3.text|text}}" } };

    NSDictionary *localized = [resource localizeConfig:config];

    XCTAssertEqualObjects(localized[@"modal"][@"title"], @"Button Alexey");
}

/// Verifies that native-config strings are substituted from the device tag cache.
- (void)testLocalizeConfigSubstitutesFromTheTagCache {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(@{ @"UserName": @"alexey" });

    NSDictionary *localized = [self.resource localizeConfig:@{ @"modal": @{ @"title": @"Hi {UserName|CapitalizeAllFirst|friend}" } }];

    XCTAssertEqualObjects(localized[@"modal"][@"title"], @"Hi Alexey");
}

/// Verifies that the native path reads the tag cache only and ignores the payload tags of the resource (Android InAppTags parity).
- (void)testLocalizeConfigIgnoresPayloadTagsAndReadsTheCache {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(@{ @"City": @"Tbilisi" });
    PWResource *resource = [[PWResource alloc] initWithDictionary:@{ @"code": @"TEST-NATIVE-CFG",
                                                                     @"url": @"https://example.com/test.zip",
                                                                     @"updated": @1,
                                                                     @"tags": @{ @"City": @"Berlin" } }];

    NSDictionary *localized = [resource localizeConfig:@{ @"modal": @{ @"title": @"{City|text|Fallback}" } }];

    XCTAssertEqualObjects(localized[@"modal"][@"title"], @"Tbilisi");
}

/// Verifies that with an empty tag cache the device tags are still substituted, instead of collapsing the whole config to its defaults.
- (void)testLocalizeConfigInjectsDeviceTagsWithAnEmptyCache {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(nil);
    /// Flags forced on so the assertion rests on the substitution, not on the test bundle's plist.
    self.configMock = OCMPartialMock([PWConfig config]);
    OCMStub([self.configMock allowCollectingDeviceModel]).andReturn(YES);
    OCMStub([self.configMock allowCollectingDeviceOsVersion]).andReturn(YES);

    NSDictionary *localized = [self.resource localizeConfig:@{ @"modal": @{ @"title": @"{Device Model|text|Fallback}" } }];

    XCTAssertEqualObjects(localized[@"modal"][@"title"], [PWUtils machineName]);
}

/// Verifies that the two device tags the server never returns are injected alongside the cached ones, so losing either write cannot stay green.
- (void)testLocalizeConfigInjectsDeviceTagsAlongsideCachedOnes {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(@{ @"City": @"Tbilisi" });
    self.configMock = OCMPartialMock([PWConfig config]);
    OCMStub([self.configMock allowCollectingDeviceModel]).andReturn(YES);
    OCMStub([self.configMock allowCollectingDeviceOsVersion]).andReturn(YES);

    NSDictionary *localized = [self.resource localizeConfig:@{ @"modal": @{ @"title": @"{Device Model|text|Fallback}",
                                                                            @"message": @"{OS Version|text|Fallback}" } }];

    XCTAssertEqualObjects(localized[@"modal"][@"title"], [PWUtils machineName]);
    XCTAssertEqualObjects(localized[@"modal"][@"message"], [PWUtils systemVersion]);
}

/// Verifies that the Country tag arrives as an ISO code and is substituted as the country name (Android convertGeoTags parity).
- (void)testLocalizeConfigResolvesCountryCodeToName {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(@{ @"Country": @"in" });

    NSDictionary *localized = [self.resource localizeConfig:@{ @"modal": @{ @"title": @"{Country|text|Fallback}" } }];

    XCTAssertEqualObjects(localized[@"modal"][@"title"], @"India");
}

/// Verifies that an unresolvable Country value drops the tag, so the placeholder renders its own default instead of the raw value.
- (void)testLocalizeConfigDropsUnknownCountryValue {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(@{ @"Country": @"No such country" });

    NSDictionary *localized = [self.resource localizeConfig:@{ @"modal": @{ @"title": @"{Country|text|Fallback}" } }];

    XCTAssertEqualObjects(localized[@"modal"][@"title"], @"Fallback");
}

/// Verifies that the City tag keeps only the city component of the "<country code>, <city>" value the server stores.
- (void)testLocalizeConfigKeepsOnlyTheCityComponent {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(@{ @"City": @"in, trivandrum" });

    NSDictionary *localized = [self.resource localizeConfig:@{ @"modal": @{ @"title": @"{City|CapitalizeFirst|Fallback}" } }];

    XCTAssertEqualObjects(localized[@"modal"][@"title"], @"Trivandrum");
}

/// Verifies that a tag placeholder written straight into native-config.json is substituted with the modifier applied.
- (void)testLocalizeConfigSubstitutesTagWrittenDirectlyInConfig {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(@{ @"City": @"Tbilisi" });

    NSDictionary *localized = [self.resource localizeConfig:@{ @"modal": @{ @"message": @"Message {City|UPPERCASE|}" } }];

    XCTAssertEqualObjects(localized[@"modal"][@"message"], @"Message TBILISI");
}

@end
