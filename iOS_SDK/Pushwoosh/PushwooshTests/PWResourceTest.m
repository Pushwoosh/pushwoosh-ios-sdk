#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWResource.h"
#import "PWCache.h"
#import "PWConfig.h"

@interface PWResourceTest : XCTestCase

@property (nonatomic, strong) id cacheMock;
@property (nonatomic, strong) id configMock;

@end

@implementation PWResourceTest

- (void)tearDown {
    /// PWCache and PWConfig are singletons, so a partial mock left standing would leak into every later suite.
    [self.cacheMock stopMocking];
    self.cacheMock = nil;
    [self.configMock stopMocking];
    self.configMock = nil;
    [super tearDown];
}

+ (NSDictionary *)dict {
    static NSDictionary *dictionary;
    if (dictionary == nil) {
        dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                      @"topbanner", @"layout",
                      @1234567890, @"updated",
                      @"1q2w3e4r5t6y7u8", @"hash",
                      @"AAAAA-11111", @"code",
                      @0, @"closeButtonType",
                      @"https://fakeurl.com/11111-AAAAA", @"url",
                      nil];
    }
    return dictionary;
}

/// Verifies that postProcessPageWithContent substitutes localized-string and dynamic-content placeholders with their default values.
- (void)testPostProcessPageWithContent {
    PWResource *resource = [[PWResource alloc] initWithDictionary:[PWResourceTest dict]];
    NSString *pageContent = @"{{LocalizedString1|text|testvalue1}}, {{LocalizedString2|text|testvalue2}}, {{tag3|templateValue3}}, {DynamicContent|String|DefaultDynamicValue}, {DynamicContent|String|}, {DynamicContentValue|String|Default}";
    NSString *content = [resource postProcessPageWithContent:pageContent];
    NSString *expected = @"testvalue1, testvalue2, tag3, DefaultDynamicValue, , Default";

    XCTAssertEqualObjects(content, expected);
}

/// Verifies the HTML path leaves device tags out when there is neither a payload tag dictionary nor a tag cache, so a shipped creative keeps rendering its default.
- (void)testPostProcessPageKeepsDeviceTagsOutWhenThereIsNoTagSourceAtAll {
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(nil);
    /// Both collection flags are forced on so the assertion below rests on the nil dictionary alone —
    /// a test bundle that ever disables device-data collection must not turn this green for free.
    self.configMock = OCMPartialMock([PWConfig config]);
    OCMStub([self.configMock allowCollectingDeviceModel]).andReturn(YES);
    OCMStub([self.configMock allowCollectingDeviceOsVersion]).andReturn(YES);
    PWResource *resource = [[PWResource alloc] initWithDictionary:[PWResourceTest dict]];

    NSString *content = [resource postProcessPageWithContent:@"{Device Model|text|Fallback}"];

    XCTAssertEqualObjects(content, @"Fallback");
}

@end
