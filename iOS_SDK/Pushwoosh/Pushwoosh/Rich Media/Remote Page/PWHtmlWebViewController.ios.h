//
//  HtmlWebViewController.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRichPushManager.h"
#import "PWSupportedOrientations.h"

#import <WebKit/WebKit.h>

@class PWHtmlWebViewController;

@protocol PWHtmlWebViewControllerDelegate <NSObject>
- (void)htmlWebViewControllerReadyForShow:(PWHtmlWebViewController *)viewController;
- (void)htmlWebViewControllerDidClose:(PWHtmlWebViewController *)viewController;
@end

@interface PWHtmlWebViewController : UIViewController

- (instancetype)initWithURLString:(NSString *)url;  //this method is to use it as a standalone webview

@property (nonatomic, weak) id<PWHtmlWebViewControllerDelegate> delegate;
@property (nonatomic) PWSupportedOrientations supportedOrientations;

@end
