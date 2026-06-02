#import <XCTest/XCTest.h>

#import "PWResource.h"

@interface PWResourceTest : XCTestCase

@end

@implementation PWResourceTest

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

@end
