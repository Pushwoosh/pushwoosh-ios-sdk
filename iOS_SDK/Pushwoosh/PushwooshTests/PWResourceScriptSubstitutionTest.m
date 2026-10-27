#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWResource.h"
#import "PWCache.h"
#import "PWConfig.h"

/// The single-brace placeholder passes must not touch an inline <script> body, while the
/// double-brace passes and the opening <script ...> tag keep working as they always did.
/// Android half of the same case table: PlaceholderSubstitutorTest.java.
@interface PWResourceScriptSubstitutionTest : XCTestCase

@property (nonatomic, strong) PWResource *resource;
@property (nonatomic, strong) id cacheMock;
@property (nonatomic, strong) id configMock;

@end

@implementation PWResourceScriptSubstitutionTest

- (void)setUp {
    [super setUp];
    self.resource = [[PWResource alloc] initWithDictionary:@{ @"code": @"TEST-SCRIPT-SUBST",
                                                              @"url": @"https://example.com/test.zip",
                                                              @"updated": @1 }];
    [[NSFileManager defaultManager] createDirectoryAtPath:[self.resource localPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    /// Real device tags would make every expectation below machine-dependent.
    self.cacheMock = OCMPartialMock([PWCache cache]);
    OCMStub([self.cacheMock getTags]).andReturn(nil);
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

#pragma mark - The four script cases

/// Verifies that a script whose body splits a string on "|" survives substitution byte for byte.
- (void)testInlineScriptSplittingOnPipeIsLeftByteForByte {
    NSString *script = @"<script>\n(function(){\n  \"use strict\";\n"
                        "  function resolve(value,fallback){if(!value)return fallback;"
                        "if(value.indexOf(\"{\"+\"{\")!==0)return value;var parts=value.slice(2,-2).split(\"|\");"
                        "return parts.length>2?parts.slice(2).join(\"|\").trim():fallback;}\n"
                        "})();\n</script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:script], script);
}

/// Verifies that a logical-or chain inside a script is left alone. This one already passes on the
/// pre-fix implementation because the iOS groups "([^|\}]+)" cannot match the empty string between
/// the two pipes of "||"; it is kept as the Android-parity pin.
- (void)testInlineScriptWithLogicalOrChainIsLeftByteForByte {
    NSString *script = @"<script>function pick(){ var x = a || b || c; return x; }</script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:script], script);
}

/// Verifies that a bitwise-or expression inside a script is left alone.
- (void)testInlineScriptWithBitwiseOrIsLeftByteForByte {
    NSString *script = @"<script>function flags(){ return READ | WRITE | EXEC; }</script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:script], script);
}

/// Verifies that placeholders around an inline script are still substituted while the script itself is kept verbatim.
- (void)testPlaceholdersNextToInlineScriptAreSubstitutedAndScriptKept {
    NSString *script = @"<script>function resolve(v){var p=v.split(\"|\");return p.slice(2).join(\"|\");}</script>";
    NSString *html = [@"<h1>{{Title|text|Hello}}</h1><p>{Name|text|friend}</p>" stringByAppendingString:script];
    NSString *expected = [@"<h1>Hello</h1><p>friend</p>" stringByAppendingString:script];

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:html], expected);
}

#pragma mark - Review focus

/// Verifies that an uppercase, attributed script tag with trailing whitespace in the closing tag is protected too.
/// The body carries "function g(){ return A|B|C; }", a brace form the single-brace pass does match, so the
/// test fails if the block regex loses NSRegularExpressionCaseInsensitive or the "\\s*" before ">".
- (void)testScriptTagUppercaseAndAttributedIsProtected {
    NSString *input = @"<SCRIPT type=\"text/javascript\">var f = A | B | C; function g(){ return A|B|C; }</SCRIPT >";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], input);
}

/// Verifies that each of several script blocks is protected while the markup between them is substituted.
/// Both bodies carry a brace form the single-brace pass does match, so the test fails if only the first
/// block is processed.
- (void)testMultipleScriptBlocksEachProtected {
    NSString *input = @"<script>a|b|c; function f(){ return A|B|C; }</script><p>{Name|text|friend}</p>"
                       "<script>d|e|f; function g(){ return D|E|F; }</script>";
    NSString *expected = @"<script>a|b|c; function f(){ return A|B|C; }</script><p>friend</p>"
                          "<script>d|e|f; function g(){ return D|E|F; }</script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected);
}

/// Verifies that an empty script body does not stop the text around it from being substituted.
/// A second, non-empty block follows: if the block regex stopped matching an empty body it would run from
/// the first opening tag to the last closing tag and swallow "{Name|text|friend}" along the way.
- (void)testEmptyScriptBodyLeavesSurroundingTextSubstituted {
    NSString *input = @"<script src=\"app.js\"></script><p>{Name|text|friend}</p>"
                       "<script>function f(){ return A|B|C; }</script>";
    NSString *expected = @"<script src=\"app.js\"></script><p>friend</p>"
                          "<script>function f(){ return A|B|C; }</script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected);
}

/// Verifies that a "</script>" inside a JS string literal ends the protected segment there, the way a
/// browser's HTML parser does. Pinned deliberately so nobody "fixes" it into a quoting-aware parser:
/// the tail after that literal is ordinary markup, so the "function f(){ return A|B|C; }" in it is
/// mangled into "function f()C; " - a quoting-aware parser would leave it whole and fail this test.
- (void)testClosingScriptInsideJsStringLiteralEndsTheSegmentThere {
    NSString *input = @"<script>var s = \"</script>\"; var x = a|b|c; function f(){ return A|B|C; }</script>";
    NSString *expected = @"<script>var s = \"</script>\"; var x = a|b|c; function f()C; </script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected);
}

/// Verifies that <style> blocks and HTML comments are NOT protected - only <script> is. The trailing
/// script block carries the same brace form as the CSS rule and comes out untouched, so the test fails
/// both if <style> became protected and if <script> stopped being.
///
/// This is a characterisation pin of an open pre-existing defect, not a statement of desired output:
/// the CSS rule "{color|x|red}" is a legal placeholder for the iOS groups "([^|\}]+)" and collapses to
/// its default, so ".a{color|x|red}" is rendered as the broken ".ared". Keeping placeholders working
/// inside <style> is intentional (3 of the 4 corpus templates rely on it); collapsing a plain CSS
/// declaration that happens to contain pipes is the defect, and it is not fixed here.
/// The Android table expects ".a" because its wider group ".[^}]+?" fails to match that form at all.
- (void)testStyleBlockAndHtmlCommentAreNotProtected {
    NSString *input = @"<style>.a{color|x|red}</style><!-- {Name|text|friend} -->"
                       "<script>.a{color|x|red}</script>";
    NSString *expected = @"<style>.ared</style><!-- friend -->"
                          "<script>.a{color|x|red}</script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected);
}

/// Verifies that a <script> inside an HTML comment does not open a script block, so the markup that
/// follows it keeps the single-brace passes a browser-parsed document would give it.
- (void)testCommentedOutScriptTagDoesNotOpenScriptBlock {
    NSString *input = @"<!-- TODO: add <script> -->\n<p>{Promo|text|SALE}</p>\n<script>var a = 1;</script>";
    NSString *expected = @"<!-- TODO: add <script> -->\n<p>SALE</p>\n<script>var a = 1;</script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected);
}

/// Verifies that "<script>" sitting in another tag's attribute value does not open a script block.
- (void)testScriptTagTextInsideAnotherTagsAttributeDoesNotOpenScriptBlock {
    NSString *input = @"<div data-tpl=\"<script>\"><p>{Promo|text|SALE}</p></div><script>var a = 1;</script>";
    NSString *expected = @"<div data-tpl=\"<script>\"><p>SALE</p></div><script>var a = 1;</script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected);
}

/// Verifies that a ">" inside a quoted attribute of the opening tag does not end it early, so a
/// placeholder in a later attribute is still substituted.
- (void)testGreaterThanInsideOpeningTagAttributeKeepsLaterPlaceholderSubstituted {
    NSString *input = @"<script data-cond=\"a>b\" src=\"t.js?uid={UserId|text|}\"></script>";
    NSString *expected = @"<script data-cond=\"a>b\" src=\"t.js?uid=\"></script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected);
}

/// Verifies that a double-brace placeholder whose default value carries a whole script block is
/// resolved as one placeholder, not cut in half by the boundary of a script segment.
- (void)testDoubleBraceDefaultContainingScriptBlockUsesItsDefault {
    NSString *input = @"<div>{{Promo|html|x <script>y()</script> z}}</div>";
    NSString *expected = @"<div>x <script>y()</script> z</div>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected);
}

#pragma mark - What a script body keeps and what it loses

/// Verifies that a double-brace placeholder inside a script body is still substituted while a single-brace
/// JavaScript expression in the same body is left alone.
- (void)testDoubleBracePlaceholderInScriptBodyIsSubstitutedAndJsExpressionIsNot {
    NSString *input = @"<script>var name = \"{{UserName|text|Guest}}\"; function f(){ return A|B|C; }</script>";
    NSString *expected = @"<script>var name = \"Guest\"; function f(){ return A|B|C; }</script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected);
}

/// Verifies that a double-brace placeholder without a default is substituted inside a script body too.
- (void)testDoubleBracePlaceholderWithoutDefaultInScriptBodyIsSubstituted {
    NSString *input = @"<script>var name = \"{{UserName|text}}\"; var f = A|B|C;</script>";
    NSString *expected = @"<script>var name = \"UserName\"; var f = A|B|C;</script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected);
}

/// Verifies that a placeholder in the opening script tag's src attribute is substituted like ordinary markup.
- (void)testPlaceholderInScriptOpeningTagIsSubstituted {
    NSString *input = @"<script src=\"https://cdn.example/t.js?uid={UserId|text|}\"></script>";
    NSString *expected = @"<script src=\"https://cdn.example/t.js?uid=\"></script>";

    XCTAssertEqualObjects([self.resource postProcessPageWithContent:input], expected);
}

/// Verifies that a script carried by a localized config value follows the same rule as one carried by a page.
- (void)testScriptInLocalizedValueKeepsDoubleBracePlaceholdersAndSkipsJsExpressions {
    NSDictionary *config = @{ @"modal": @{ @"text": @"<script src=\"t.js?uid={UserId|text|}\">"
                                                     "var n = \"{{UserName|text|Guest}}\"; function f(){ return A|B|C; }</script>" } };

    NSDictionary *localized = [self.resource localizeConfig:config];

    XCTAssertEqualObjects(localized[@"modal"][@"text"],
                          @"<script src=\"t.js?uid=\">var n = \"Guest\"; function f(){ return A|B|C; }</script>");
}

/// Verifies that an unpaired "<script" inside a localized config value does not disable substitution for the rest of that value.
- (void)testUnpairedScriptTagInLocalizedValueStillSubstitutes {
    NSDictionary *config = @{ @"modal": @{ @"text": @"a <script tip {Name|text|friend} tail" } };

    NSDictionary *localized = [self.resource localizeConfig:config];

    XCTAssertEqualObjects(localized[@"modal"][@"text"], @"a <script tip friend tail");
}

@end
