#import <XCTest/XCTest.h>
#import "PWWebClient.h"
#import "PWUtils.h"

@interface PWWebClient (Test)

+ (PWLinkAction)pw_linkActionForURL:(NSURL *)url;

@end

@interface PWWebClientLinkActionTest : XCTestCase
@end

@implementation PWWebClientLinkActionTest

- (PWLinkAction)actionForString:(NSString *)urlString {
    return [PWWebClient pw_linkActionForURL:[NSURL URLWithString:urlString]];
}

/// Verifies that the pushwoosh:// bridge scheme is routed to the bridge regardless of letter case.
- (void)testPushwooshSchemeIsBridge {
    XCTAssertEqual([self actionForString:@"pushwoosh://createTestDevice"], PWLinkActionBridge);
    XCTAssertEqual([self actionForString:@"PUSHWOOSH://createTestDevice"], PWLinkActionBridge);
}

/// Verifies that in-content schemes are consumed without closing the in-app, as they were before SDK-883.
- (void)testInContentSchemesAreIgnored {
    XCTAssertEqual([self actionForString:@"javascript:void(0)"], PWLinkActionIgnore);
    XCTAssertEqual([self actionForString:@"about:blank"], PWLinkActionIgnore);
    XCTAssertEqual([self actionForString:@"data:text/html,x"], PWLinkActionIgnore);
    XCTAssertEqual([self actionForString:@"blob:abcd"], PWLinkActionIgnore);
}

/// Verifies that a schemeless link is consumed rather than treated as an external URL.
- (void)testSchemelessLinkIsIgnored {
    XCTAssertEqual([self actionForString:@"page2.html"], PWLinkActionIgnore);
    XCTAssertEqual([self actionForString:@"#anchor"], PWLinkActionIgnore);
}

/// Verifies that any local file URL closes the in-app without an open attempt, preserving pre-SDK-883 behaviour.
- (void)testLocalFileURLClosesOnly {
    XCTAssertEqual([self actionForString:@"file:///creative/index.html"], PWLinkActionCloseOnly);
    XCTAssertEqual([self actionForString:@"file:///creative/index.html#anchor"], PWLinkActionCloseOnly);
    XCTAssertEqual([self actionForString:@"file:///creative/index.html?x=1"], PWLinkActionCloseOnly);
    XCTAssertEqual([self actionForString:@"file:///creative/page2.html"], PWLinkActionCloseOnly);
    XCTAssertEqual([self actionForString:@"FILE:///creative/page2.html"], PWLinkActionCloseOnly);
}

/// Verifies that external URLs close the in-app and are handed to the system, including opaque and unopenable schemes.
- (void)testExternalURLsCloseAndOpen {
    XCTAssertEqual([self actionForString:@"https://example.com/promo?token=abc"], PWLinkActionCloseAndOpen);
    XCTAssertEqual([self actionForString:@"http://example.com"], PWLinkActionCloseAndOpen);
    XCTAssertEqual([self actionForString:@"instagram://user?username=pushwoosh"], PWLinkActionCloseAndOpen);
    XCTAssertEqual([self actionForString:@"tel:12345"], PWLinkActionCloseAndOpen);
    XCTAssertEqual([self actionForString:@"mailto:a@b.c"], PWLinkActionCloseAndOpen);
    XCTAssertEqual([self actionForString:@"itms-apps://apple.com/app"], PWLinkActionCloseAndOpen);
    XCTAssertEqual([self actionForString:@"nonexistentapp12345://foo"], PWLinkActionCloseAndOpen);
}

/// Verifies that the log description keeps scheme and host only, so tokens, phone numbers and emails never reach os_log.
- (void)testLoggableURLDescriptionRedactsEverythingButSchemeAndHost {
    XCTAssertEqualObjects([PWUtils loggableURLDescription:[NSURL URLWithString:@"https://example.com/reset?token=secret"]], @"https://example.com");
    XCTAssertEqualObjects([PWUtils loggableURLDescription:[NSURL URLWithString:@"nonexistentapp12345://foo"]], @"nonexistentapp12345://foo");
    XCTAssertEqualObjects([PWUtils loggableURLDescription:[NSURL URLWithString:@"tel:12345"]], @"tel:");
    XCTAssertEqualObjects([PWUtils loggableURLDescription:[NSURL URLWithString:@"mailto:user@example.com"]], @"mailto:");
    XCTAssertEqualObjects([PWUtils loggableURLDescription:[NSURL URLWithString:@"sms:+79001234567"]], @"sms:");
    XCTAssertEqualObjects([PWUtils loggableURLDescription:[NSURL fileURLWithPath:@"/tmp/creative/index.html"]], @"file:");
    XCTAssertEqualObjects([PWUtils loggableURLDescription:[NSURL URLWithString:@"page2.html"]], @"(no scheme):");
    XCTAssertEqualObjects([PWUtils loggableURLDescription:[NSURL URLWithString:@"TEL:12345"]], @"tel:");
    XCTAssertEqualObjects([PWUtils loggableURLDescription:[NSURL URLWithString:@"HTTPS://Example.COM/p"]], @"https://example.com");
}

@end
