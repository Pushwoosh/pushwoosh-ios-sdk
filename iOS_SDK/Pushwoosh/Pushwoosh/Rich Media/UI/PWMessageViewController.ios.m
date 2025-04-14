//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PWPushRuntime.h"
#import "PWMessageViewController.h"
#import "PWInteractionDisabledWindow.h"
#import "PWInteractionDisabledView.h"
#import "PWPushManagerJSBridge.h"
#import "PWUtils.h"
#import "PWSupportedOrientations.h"
#import "PWRichMediaManager.h"
#import "PWRichMedia+Internal.h"
#import "PWRichMediaStyle.h"
#import "PWRichMediaView.h"
#import "PWBusinessCaseManager.h"

#import <objc/runtime.h>

@interface PWMessageViewController () {
    BOOL appeared;
}

@property (nonatomic) PWRichMedia *richMedia;
@property (nonatomic) PWRichMediaView *richMediaView;
@property (nonatomic) void(^completion)(BOOL success);
@property (nonatomic) BOOL succeeded;
@property (nonatomic) BOOL webContentLoaded;
@property (nonatomic) BOOL statusBarInitiallyHidden;
@property (nonatomic) BOOL closeButtonTimerExpired;

@property (nonatomic) UIButton *closeButton;

@end

@implementation PWMessageViewController

+ (void)presentWithRichMedia:(PWRichMedia *)richMedia {
    [self presentWithRichMedia:richMedia completion:nil];
}

+ (void)presentWithRichMedia:(PWRichMedia *)richMedia completion:(void (^)(BOOL success))completion {
    BOOL shouldShow = YES;
    
    if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:shouldPresentRichMedia:)]) {
        shouldShow = [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager] shouldPresentRichMedia:richMedia];
    }
    
    if (!richMedia.resource.locked && shouldShow) {
        UIWindow *presentedWindow = [self presentedWindow];
        
        PWMessageViewController *viewController = [[self alloc] initWithRichMedia:richMedia
                                                                           window:presentedWindow
                                                                   richMediaStyle:[PWRichMediaManager sharedManager].richMediaStyle
                                                                       completion:completion];
        [viewController presentInWindow:presentedWindow];
    }
}

- (instancetype)initWithRichMedia:(PWRichMedia *)richMedia window:(UIWindow *)window richMediaStyle:(PWRichMediaStyle *)style completion:(void(^)(BOOL success))completion {
    if (self = [self initWithWindow:window richMediaStyle:style]) {
        _richMedia = richMedia;
        _completion = completion;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _succeeded = YES;
    
    //used if there is not ViewController based statusbar appearance
    _statusBarInitiallyHidden = [UIApplication sharedApplication].statusBarHidden;
    
    _richMediaView = [[PWRichMediaView alloc] initWithFrame:self.view.bounds
                                                    payload:_richMedia.pushPayload
                                                       code:(_richMedia.resource.isRichMedia ? _richMedia.content : @"")
                                                  inAppCode:(!_richMedia.resource.isRichMedia ? _richMedia.content : @"")];
    _richMediaView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_richMediaView];
    
    __weak typeof (self) wself = self;
    
    NSString *isDebug = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"Pushwoosh_DEBUG"];
    dispatch_block_t block = ^{
        [_richMediaView loadRichMedia:_richMedia completion:^(NSError *error) {
            if (error) {
                [wself richMediaViewDidFailWithError:error];
            } else {
                [wself didLoadRichMediaView];
            }
        }];
    };
    
    if (isDebug) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            block();
        });
    } else {
        block();
    }
    
    if (self.richMediaStyle.allowsInlineMediaPlayback != nil) {
        _richMediaView.webClient.webView.configuration.allowsInlineMediaPlayback = [self.richMediaStyle.allowsInlineMediaPlayback boolValue];
    }
    
    if (self.richMediaStyle.mediaPlaybackRequiresUserAction != nil) {
        _richMediaView.webClient.webView.configuration.mediaPlaybackRequiresUserAction = self.richMediaStyle.mediaPlaybackRequiresUserAction.boolValue;
    }
    
    _richMediaView.closeActionBlock = ^{
        [wself didCloseRichMediaView];
    };
    
    if (_richMedia.resource.presentationStyle == IAResourcePresentationCenter) {
        _richMediaView.webClient.webView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    } else if (_richMedia.resource.presentationStyle == IAResourcePresentationCenter) {
        _richMediaView.webClient.webView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth;
    } else if (_richMedia.resource.presentationStyle == IAResourcePresentationBottomBanner) {
        _richMediaView.webClient.webView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    }
    
	_closeButton = [PWUtils webViewCloseButton];
	[_closeButton addTarget:_richMediaView.webClient action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    
    self.loadingView.alpha = 0.0f;
    self.loadingView.cancelLoadingButton.alpha = 0.0f;
    _richMediaView.alpha = 0.0;

    [self performSelector:@selector(showLoadingView) withObject:nil afterDelay:0.5f];
    [self performSelector:@selector(conditionallyShowCloseButton) withObject:nil afterDelay:self.richMediaStyle.closeButtonPresentingDelay];
}

- (void)showLoadingView {
    [UIView animateWithDuration:PWRichMediaStyleDefaultAnimationDuration
                     animations:^{
                         self.loadingView.alpha = 1.0f;
                     } completion:nil];
}

- (void)conditionallyShowCloseButton {
    if (_webContentLoaded) {
        if (_richMedia.resource.closeButton) {
            if (_richMedia.resource.presentationStyle == IAResourcePresentationFullScreen) {
                [_richMediaView.webClient.webView addSubview:_closeButton];
            } else {
                [self.view addSubview:_closeButton];
            }
            
            _closeButton.alpha = 0.0f;
            
            [UIView animateWithDuration:PWRichMediaStyleDefaultAnimationDuration animations:^{
                _closeButton.alpha = 1.0f;
            }];
        }
    } else {
        self.loadingView.cancelLoadingButton.alpha = 0.0f;
        
        [UIView animateWithDuration:PWRichMediaStyleDefaultAnimationDuration animations:^{
            self.loadingView.cancelLoadingButton.alpha = 1.0f;
        }];
    }
    
    _closeButtonTimerExpired = YES;
}

- (void)runAnimation {
    _richMediaView.alpha = 1.0;
    
    dispatch_block_t completion = ^{
        if (!appeared) {
            appeared = YES;
            [self updateStatusBar];
        }
    };
    
    if (self.richMediaStyle.animationDelegate) {
        [self.richMediaStyle.animationDelegate runPresentingAnimationWithContentView:_richMediaView parentView:self.view completion:completion];
    } else {
        completion();
    }
    
    [UIView animateWithDuration:PWRichMediaStyleDefaultAnimationDuration animations:^{
        self.view.backgroundColor = self.richMediaStyle.backgroundColor;
    }];
}

- (void)updateStatusBar {
    NSNumber *statusBarVCBasedAppearance = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIViewControllerBasedStatusBarAppearance"];
    
    if (statusBarVCBasedAppearance && !statusBarVCBasedAppearance.boolValue) {
        if (appeared) {
            [[UIApplication sharedApplication] setStatusBarHidden:self.richMediaStyle.shouldHideStatusBar withAnimation:UIStatusBarAnimationFade];
        } else {
            [[UIApplication sharedApplication] setStatusBarHidden:_statusBarInitiallyHidden withAnimation:UIStatusBarAnimationFade];
        }
    } else {
        [UIView animateWithDuration:PWRichMediaStyleDefaultAnimationDuration animations:^{
            [self setNeedsStatusBarAppearanceUpdate];
        }];
    }
}

- (void)closeController {
    _richMedia.resource.locked = NO;
    
    appeared = NO;
    
    [self updateStatusBar];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_richMedia.resource.presentationStyle != IAResourcePresentationFullScreen) {
            [UIView animateKeyframesWithDuration:0.1
                                           delay:0.0
                                         options:UIViewKeyframeAnimationOptionCalculationModeDiscrete
                                      animations:^{
                                          _closeButton.alpha = 0.0f;
                                      }
                                      completion:nil
             ];
        }
        
        [[PWBusinessCaseManager sharedManager] resourceDidClosed:_richMedia.resource];
        
        if (_completion) {
            _completion(_succeeded);
        }
    });
    
    [UIView animateWithDuration:PWRichMediaStyleDefaultAnimationDuration animations:^{
        self.view.backgroundColor = [UIColor clearColor];
    }];
    
    dispatch_block_t completion = ^{
       [super closeController];
        
        if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:didCloseRichMedia:)]) {
            [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager] didCloseRichMedia:_richMedia];
        }
    };
    
    if (self.richMediaStyle.animationDelegate) {
        [self.richMediaStyle.animationDelegate runDismissingAnimationWithContentView:_richMediaView parentView:self.view completion:completion];
    } else {
        completion();
    }
}

- (BOOL)prefersStatusBarHidden {
    return appeared && self.richMediaStyle.shouldHideStatusBar;
}

- (void)didLoadRichMediaView {
    if (_webContentLoaded) { //For some reason this method could be called several times for single Rich Media. Possibly because of iframe container.
        return;
    }
    _webContentLoaded = YES;
    
    if (_richMedia.resource.presentationStyle != IAResourcePresentationFullScreen && _richMedia.resource.presentationStyle != IAResourcePresentationTopBanner) {
        CGRect frame = _richMediaView.webClient.webView.frame;
        CGFloat height = _richMediaView.contentSize.height;
        
        if (height > 1.0) {
            if (_richMedia.resource.presentationStyle == IAResourcePresentationCenter) {
                frame.origin = CGPointMake(0.0, self.view.frame.size.height / 2.0 - height / 2.0);
            } else if (_richMedia.resource.presentationStyle == IAResourcePresentationBottomBanner) {
                frame.origin = CGPointMake(0.0, self.view.frame.size.height - height);
            }
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"Inapp measurement failed"];
        }
        
        _richMediaView.webClient.webView.frame = frame;
    }
	
    if (_closeButtonTimerExpired) {
        [self conditionallyShowCloseButton];
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showLoadingView) object:nil];
    
    __weak typeof(self) wself = self;
	[UIView animateWithDuration:PWRichMediaStyleDefaultAnimationDuration animations:^{
        wself.loadingView.alpha = 0;
    } completion:^(BOOL finished) {
        [wself.loadingView removeFromSuperview];
    }];
    
    [self runAnimation];
    
    if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:didPresentRichMedia:)]) {
        [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager] didPresentRichMedia:_richMedia];
    }
}

- (void)richMediaViewDidFailWithError:(NSError *)error {
    _succeeded = NO;
    [self closeController];
    
    if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:presentingDidFailForRichMedia:withError:)]) {
        [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager]
                                        presentingDidFailForRichMedia:_richMedia
                                                            withError:error ? : [PWUtils pushwooshError:@"No HTML content"]];
    }
}

- (void)didCloseRichMediaView {
    _succeeded = YES;
    [self closeController];
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showLoadingView) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(conditionallyShowCloseButton) object:nil];
}
     
@end
