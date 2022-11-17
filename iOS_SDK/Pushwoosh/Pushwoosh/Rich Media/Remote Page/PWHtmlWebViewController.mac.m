//
//  PWHtmlWebViewController.m
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWHtmlWebViewController.mac.h"
#import <WebKit/WebKit.h>

@interface PWHtmlWebViewController () <WKNavigationDelegate>

@property (nonatomic, copy) NSString *urlToLoad;
@property (nonatomic) NSInteger webViewLoads;
@property (nonatomic, strong) WKWebView *webView;

@end

@implementation PWHtmlWebViewController

- (instancetype)initWithURLString:(NSString *)url {
	NSRect screenSize = [[NSScreen mainScreen] frame];

	CGFloat percent = 0.6;

	CGFloat offset = (1.0 - percent) / 2.0;

	NSRect windowRect = NSMakeRect(screenSize.size.width * offset, screenSize.size.height * offset, screenSize.size.width * percent, screenSize.size.height * percent);
	NSWindow *window = [[NSWindow alloc] initWithContentRect:windowRect styleMask:NSTitledWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask | NSClosableWindowMask backing:NSBackingStoreBuffered defer:false];
	if (self = [super initWithWindow:window]) {
		_urlToLoad = url;
		_webViewLoads = 0;
		WKWebViewConfiguration *config = [WKWebViewConfiguration new];
		_webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, self.window.frame.size.width, self.window.frame.size.height) configuration:config];
		_webView.navigationDelegate = self;
		self.window.contentView = _webView;
		[_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:_urlToLoad]]];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:self.window];
	}

	return self;
}

- (void)windowWillClose:(NSNotification *)notification {
	if ([self.delegate respondsToSelector:@selector(htmlWebViewControllerDidClose:)])
		[self.delegate htmlWebViewControllerDidClose:self];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
	if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSWorkspace sharedWorkspace] openURL:[navigationAction.request URL]];
		});

		[self.window close];
		decisionHandler(WKNavigationActionPolicyCancel);
	}
	decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
	_webViewLoads++;
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
	_webViewLoads--;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
	_webViewLoads--;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
	_webViewLoads--;

	if (_webViewLoads == 0) {
		//webview is visible and shouldn't be showed anymore
		_webViewLoads = 1000;
		self.window.title = webView.title;
		if ([self.delegate respondsToSelector:@selector(htmlWebViewControllerReadyForShow:)])
			[self.delegate htmlWebViewControllerReadyForShow:self];
	}
}

@end
