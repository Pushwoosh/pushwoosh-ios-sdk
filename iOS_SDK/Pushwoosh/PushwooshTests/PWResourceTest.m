
#import <XCTest/XCTest.h>

#import "PWResource.h"

@interface PWResourceTest : XCTestCase

@end

@implementation PWResourceTest

+ (NSDictionary *)dict {
    static NSDictionary *dictionary;
    if (dictionary == nil) {
        dictionary =  [[NSDictionary alloc] initWithObjectsAndKeys: @"topbanner", @"layout", @1234567890, @"updated", @"1q2w3e4r5t6y7u8", @"hash", @"AAAAA-11111", @"code", @0, @"closeButtonType", @"Consent", @"gdpr", @"", @"businessCase", @"NO", @"required", @0, @"priority", @"https://fakeurl.com/11111-AAAAA", @"url", nil];
    }
    return dictionary;
}

+ (NSArray*)richMediaIds {
	static NSArray *ids;
	if (ids == nil) {
		ids = @[ @"DAA83-1066A", @"1A76D-BE817", @"14A50-5B4EB" ];
	}
	return ids;
}

+ (NSString*)richMediaBaseUrl {
	return @"https://richmedia-pwdock.arello-mobile.com/uploads/richmedia/";
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testPostProcessPageWithContent {
    
    PWResource *resource = [[PWResource alloc] initWithDictionary:[PWResourceTest dict]];
    NSString *pageContent = @"{{LocalizedString1|text|testvalue1}}, {{LocalizedString2|text|testvalue2}}, {{tag3|templateValue3}}, {DynamicContent|String|DefaultDynamicValue}, {DynamicContent|String|}, {DynamicContentValue|String|Default}";
    NSString *content = [resource postProcessPageWithContent:pageContent];
    NSString *expected = @"testvalue1, testvalue2, tag3, DefaultDynamicValue, , Default";
    
    XCTAssertEqualObjects(content, expected);
}
/*
// TODO: enable test
- (void)disabledTestRichMediaResources {
	for (NSString *richMediaId in [PWResourceTest richMediaIds]) {
		XCTestExpectation *downloadExpectation = [self expectationWithDescription:@"resource loaded"];
		
		NSString *richMediaUrl = [[[PWResourceTest richMediaBaseUrl] stringByAppendingString:richMediaId] stringByAppendingString: @".zip"];
		PWResource *resource = [[PWResource alloc] initWithDictionary:@{ @"code": richMediaId, @"url" : richMediaUrl, @"closeButtonType" : @"YES", @"layout" : @"topbanner" }];
		[resource downloadDataWithCompletion:nil];
		
		[resource getHTMLDataWithCompletion:^(NSString* htmlData) {
			XCTAssertNotNil(htmlData);
			
			// TODO: assert htmlData content
			[downloadExpectation fulfill];
		} timeoutSec:10];
		
		[self waitForExpectationsWithTimeout:5 handler:nil];
	}
}
*/
@end
