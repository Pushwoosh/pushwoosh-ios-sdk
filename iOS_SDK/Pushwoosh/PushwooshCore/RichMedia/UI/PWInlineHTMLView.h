//
//  PWInlineHTMLView.h
//  PushwooshCore
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

/// HTML document of an inline banner drawn by the Rich Media web view, embedded in a slot of the
/// PushwooshInApp module. Follows the interface style of its superview. For internal use.
@interface PWInlineHTMLView : UIView

@property (nonatomic, readonly) WKWebView *webView;

/// Called by `pushwoosh.closeInApp()`.
@property (nonatomic, copy, nullable) dispatch_block_t closeInApp;

/// Called by `pushwoosh.registerForPushNotifications()` and `pushwoosh.openAppSettings()`, before they close
/// the document through `closeInApp`.
@property (nonatomic, copy, nullable) dispatch_block_t closingActionDidRun;

/// Asked before `pushwoosh.postEvent()` of the document is sent; NO drops the event.
@property (nonatomic, copy, nullable) BOOL (^shouldPostEvent)(void);

/// Loads the document; links open over it, the JS API of Rich Media works, no in-app show is tracked.
- (void)loadHTMLString:(NSString *)html;

@end

NS_ASSUME_NONNULL_END
#endif
