#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <WebKit/WebKit.h>
#import "PWRichMediaView.h"
#import "PWRichMedia.h"
#import "PWWebClient.h"
#import "PWManagerBridge.h"
#import "PWInAppMessagesManager.h"

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

/// Verifies that an HTML string reports the size of its content to the owner.
- (void)testHTMLStringReportsContentSize {
    PWRichMediaView *view = [[PWRichMediaView alloc] initWithFrame:CGRectMake(0, 0, 320, 1) payload:nil code:nil inAppCode:nil];
    __block NSInteger changes = 0;
    view.contentSizeDidChangeBlock = ^{
        changes += 1;
    };
    [view loadHTMLString:@"<html><body>Sale</body></html>" completion:nil];

    view.webClient.webView.scrollView.contentSize = CGSizeMake(320, 180);

    XCTAssertGreaterThan(changes, 0);
    XCTAssertEqualWithAccuracy(view.contentSize.height, 180.0, 0.001);
    XCTAssertTrue(view.webClient.opensLinksWithoutClosing);
}

/// Verifies that a loaded HTML string completes without tracking an in-app show.
- (void)testHTMLStringFinishCompletesWithoutInAppShow {
    id bridge = OCMPartialMock([PWManagerBridge shared]);
    id inAppManager = OCMClassMock([PWInAppMessagesManager class]);
    OCMStub([bridge inAppMessagesManager]).andReturn(inAppManager);
    OCMReject([inAppManager trackInAppWithCode:OCMOCK_ANY action:OCMOCK_ANY messageHash:OCMOCK_ANY]);
    PWRichMediaView *view = [[PWRichMediaView alloc] initWithFrame:CGRectMake(0, 0, 320, 1) payload:nil code:nil inAppCode:nil];
    __block BOOL completed = NO;
    [view loadHTMLString:@"<html><body>Sale</body></html>" completion:^(NSError *error) {
        completed = error == nil;
    }];

    [view webClientDidFinishLoad:view.webClient];

    XCTAssertTrue(completed);
    OCMVerifyAll(inAppManager);
    [bridge stopMocking];
}

@end
