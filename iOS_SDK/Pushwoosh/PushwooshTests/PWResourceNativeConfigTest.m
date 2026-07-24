
#import <XCTest/XCTest.h>
#import "PWResource.h"

@interface PWResourceNativeConfigTest : XCTestCase

@property (nonatomic, strong) PWResource *resource;

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

@end
