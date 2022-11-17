//
//  RichPushManager.m
//	Pushwoosh SDK
//

#import "PWRichPushManager.h"
#import "PWHtmlWebViewController.mac.h"
#import "PWRequestManager.h"
#import "PWPreferences.h"
#import "PWSupportedOrientations.h"

@interface PWRichPushManager () <PWHtmlWebViewControllerDelegate>

@property (nonatomic, strong) PWHtmlWebViewController *htmlWindowController;

@property (nonatomic, assign) PWSupportedOrientations supportedOrientations;

@end

@implementation PWRichPushManager

- (instancetype)init {
	if (self = [super init]) {
	}
	return self;
}

- (void)showPushPage:(NSString *)pageId {
	NSString *baseUrlHost = [[NSURL URLWithString:[[PWPreferences preferences] baseUrl]] host];
	[self showHTMLViewControllerWithURLString:[NSString stringWithFormat:kServiceHtmlContentFormatUrl, baseUrlHost, pageId]];
}

- (void)showCustomPushPageWithURLString:(NSString *)URLString {
	[self showHTMLViewControllerWithURLString:URLString];
}

- (void)showHTMLViewControllerWithURLString:(NSString *)urlString {
	PWLogDebug(@"URLString: %@", urlString);
    dispatch_async(dispatch_get_main_queue(), ^{
        _htmlWindowController = [[PWHtmlWebViewController alloc] initWithURLString:urlString];
        _htmlWindowController.delegate = self;
        [_htmlWindowController window];
    });
}

- (void)showWebView {
	[_htmlWindowController showWindow:nil];
}

#pragma mark - HtmlWebViewControllerDelegate

- (void)htmlWebViewControllerReadyForShow:(PWHtmlWebViewController *)viewController {
	[self showWebView];
}

- (void)htmlWebViewControllerDidClose:(PWHtmlWebViewController *)viewController {
}

#pragma mark -

@end
