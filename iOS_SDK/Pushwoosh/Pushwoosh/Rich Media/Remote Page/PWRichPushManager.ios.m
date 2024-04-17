//
//  RichPushManager.m
//	Pushwoosh SDK
//

#import "PWRichPushManager.h"

#import "PWHtmlWebViewController.ios.h"
#import "PWRequestManager.h"
#import "PWPreferences.h"
#import "Constants.h"

@interface PWRichPushManager () <PWHtmlWebViewControllerDelegate>

@property (nonatomic, strong) UIWindow *richPushWindow;

@property (nonatomic, assign) PWSupportedOrientations supportedOrientations;

@end

@implementation PWRichPushManager

- (instancetype)init {
    if (self = [super init]) {
        _richPushWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _supportedOrientations = PWOrientationPortrait | PWOrientationPortraitUpsideDown | PWOrientationLandscapeLeft | PWOrientationLandscapeRight;
        }
        return self;
    }

- (void)showPushPage:(NSString *)pageId {
	[self showHTMLViewControllerWithURLString:[NSString stringWithFormat:kServiceHtmlContentFormatUrl, @"go.pushwoosh.com", pageId]];
}

- (void)showCustomPushPageWithURLString:(NSString *)URLString {
	[self showHTMLViewControllerWithURLString:URLString];
}

- (void)showHTMLViewControllerWithURLString:(NSString *)urlString {
    dispatch_async(dispatch_get_main_queue(), ^{
        PWHtmlWebViewController *vc = [[PWHtmlWebViewController alloc] initWithURLString:urlString];
        vc.delegate = self;
        vc.supportedOrientations = _supportedOrientations;

        self.richPushWindow.rootViewController = vc;
        [vc view];
    });
}

- (void)showWebView {
	self.richPushWindow.hidden = NO;

	CGAffineTransform originalTransform = self.richPushWindow.rootViewController.view.transform;
	self.richPushWindow.rootViewController.view.alpha = 0.0f;
	self.richPushWindow.rootViewController.view.transform = CGAffineTransformConcat(originalTransform, CGAffineTransformMakeScale(0.01f, 0.01f));

	[UIView animateWithDuration:0.3
						  delay:0
						options:UIViewAnimationOptionCurveEaseIn
					 animations:^{
						 self.richPushWindow.rootViewController.view.transform = CGAffineTransformConcat(originalTransform, CGAffineTransformMakeScale(1.0f, 1.0f));
						 self.richPushWindow.rootViewController.view.alpha = 1.0f;
					 }
					 completion:nil];
}

- (void)hidePushWindow {
	[UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut
		animations:^{
			self.richPushWindow.rootViewController.view.transform = CGAffineTransformScale(self.richPushWindow.rootViewController.view.transform, 0.01f, 0.01f);
			self.richPushWindow.rootViewController.view.alpha = 0.0f;
		}
		completion:^(BOOL finished) {
			self.richPushWindow.hidden = YES;
			self.richPushWindow.rootViewController = nil;
		}
	];
}

#pragma mark - HtmlWebViewControllerDelegate

- (void)htmlWebViewControllerReadyForShow:(PWHtmlWebViewController *)viewController {
	[self showWebView];
}

- (void)htmlWebViewControllerDidClose:(PWHtmlWebViewController *)viewController {
	[self hidePushWindow];
}

#pragma mark -

@end
