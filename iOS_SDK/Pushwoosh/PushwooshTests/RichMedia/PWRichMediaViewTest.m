#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <WebKit/WebKit.h>
#import "PWRichMediaView.h"
#import "PWRichMedia.h"
#import "PWWebClient.h"

@interface PWRichMediaView (Test)
- (void)refreshContentSize;
@end

@interface PWRichMediaViewTest : XCTestCase
@end

@implementation PWRichMediaViewTest

/// Verifies that refreshContentSize falls back to height 1 when no rich media is loaded.
- (void)testRefreshContentSizeFallsBackToHeightOneWithoutRichMedia {
    PWRichMediaView *view = [[PWRichMediaView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];

    [view refreshContentSize];

    XCTAssertEqualWithAccuracy(view.contentSize.height, 1.0, 0.001);
    XCTAssertEqualWithAccuracy(view.contentSize.width, 320.0, 0.001);
}

/// Verifies that refreshContentSize falls back to height 1 when the web view has not reported a content size yet.
- (void)testRefreshContentSizeFallsBackToHeightOneWhenContentSizeNotReported {
    PWRichMediaView *view = [[PWRichMediaView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    webView.scrollView.contentSize = CGSizeZero;

    id webClient = OCMClassMock([PWWebClient class]);
    OCMStub([webClient webView]).andReturn(webView);
    view.webClient = webClient;
    [view setValue:OCMClassMock([PWRichMedia class]) forKey:@"richMedia"];

    [view refreshContentSize];

    XCTAssertEqualWithAccuracy(view.contentSize.height, 1.0, 0.001);
    XCTAssertEqualWithAccuracy(view.contentSize.width, 320.0, 0.001);

    /// The view never registered the contentSize observer for this web view, so dealloc must not reach it.
    view.webClient = nil;
    [webClient stopMocking];
}

@end
