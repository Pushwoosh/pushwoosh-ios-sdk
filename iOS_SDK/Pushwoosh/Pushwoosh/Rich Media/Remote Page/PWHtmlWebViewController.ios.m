//
//  HtmlWebViewController.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWHtmlWebViewController.ios.h"
#import "PWUtils.h"
#import <QuartzCore/QuartzCore.h>

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

@interface PWHtmlWebViewController () <WKNavigationDelegate>

@property (nonatomic, copy) NSString *urlToLoad;
@property (nonatomic) NSInteger webViewLoads;
@property (nonatomic, strong) WKWebView *webView;

@end

@implementation PWHtmlWebViewController

- (instancetype)initWithURLString:(NSString *)url {
	if (self = [super init]) {
		_urlToLoad = url;
		_webViewLoads = 0;
	}

	return self;
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = @"";
	_webViewLoads = 0;

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    _webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) configuration:configuration];
    _webView.navigationDelegate = self;
    _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_webView];

	UIButton *closeButton = [PWUtils webViewCloseButton];
	[closeButton addTarget:self action:@selector(closeButtonAction) forControlEvents:UIControlEventTouchUpInside];
	[_webView addSubview:closeButton];

    _webView.backgroundColor = [UIColor clearColor];
    _webView.opaque = NO;
    _webView.scrollView.bounces = NO;

	[_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:_urlToLoad]]];
}

- (void)dealloc {
	self.delegate = nil;
	_webView.navigationDelegate = nil;
}

- (void)closeButtonAction {
	if ([self.delegate respondsToSelector:@selector(htmlWebViewControllerDidClose:)])
		[self.delegate htmlWebViewControllerDidClose:self];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return ((_supportedOrientations & PWOrientationPortrait) ? UIInterfaceOrientationMaskPortrait : 0) | ((_supportedOrientations & PWOrientationPortraitUpsideDown) ? UIInterfaceOrientationMaskPortraitUpsideDown : 0) | ((_supportedOrientations & PWOrientationLandscapeLeft) ? UIInterfaceOrientationMaskLandscapeLeft : 0) | ((_supportedOrientations & PWOrientationLandscapeRight) ? UIInterfaceOrientationMaskLandscapeRight : 0);
}

- (BOOL)shouldAutorotate {
	return YES;
}

#pragma mark WKWebViewNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    _webViewLoads++;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    _webViewLoads--;

    if (_webViewLoads == 0) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

        //webview is visible and shouldn't be showed anymore
        _webViewLoads = 1000;

        if ([self.delegate respondsToSelector:@selector(htmlWebViewControllerReadyForShow:)])
            [self.delegate htmlWebViewControllerReadyForShow:self];
    }
}
    
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    _webViewLoads--;

    if ([error code] != -999) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated || navigationAction.navigationType == WKNavigationTypeFormSubmitted) {
        //If url has custom scheme like facebook:// or itms:// we need to open it directly:
        //fix to prevent app freeezes on iOS7
        //see: http://stackoverflow.com/questions/19356488/openurl-freezes-app-for-over-10-seconds
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] openURL:navigationAction.request.URL options:@{} completionHandler:nil];
        });

        //close the webview
        [self closeButtonAction];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}


@end
