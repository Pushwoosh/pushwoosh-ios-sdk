//
//  PWBaseLoadingViewController.m
//  Pushwoosh
//
//  Created by Victor Eysner on 05/12/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//
#if TARGET_OS_IOS || TARGET_OS_WATCH

#import "PWBaseLoadingViewController.h"
#import "PWInteractionDisabledWindow.h"
#import "PWInteractionDisabledView.h"
#import "PWUtils.h"

@interface PWBaseLoadingViewController ()

@property (nonatomic) UIInterfaceOrientationMask supportedOrientations;
@property (nonatomic) UIStatusBarStyle barStyle;
@property (nonatomic) UIWindow *window;

@end

@implementation PWBaseLoadingViewController


+ (UIWindow *)presentedWindow {
    CGRect bounds = [UIScreen mainScreen].bounds;
    UIWindow *presentedWindow = [[PWInteractionDisabledWindow alloc] initWithFrame:bounds];
    presentedWindow.hidden = YES;
    presentedWindow.windowLevel = UIWindowLevelNormal + ([UIViewController instancesRespondToSelector:@selector(restoresFocusAfterTransition)] ? 1 : 0); //iOS 10 check
    
    return presentedWindow;
}

- (void)presentInWindow:(UIWindow *)window {
    window.rootViewController = self;
    
    Class sceneClass = NSClassFromString(@"UIWindowScene");
    
    if (sceneClass) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wpartial-availability"
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        
        SEL scenesSelector = NSSelectorFromString(@"connectedScenes");
        SEL setWindowSceneSelector = NSSelectorFromString(@"setWindowScene:");
        NSArray *scenes = [(id)UIApplication.sharedApplication performSelector:scenesSelector];
        
        for (id scene in scenes) {
            if ([scene isKindOfClass:sceneClass]) {
                [window performSelector:setWindowSceneSelector withObject:scene];
                break;
            }
        }

        #pragma clang diagnostic pop
    }
    
    self.view.frame = window.bounds;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [window makeKeyAndVisible];
}

- (instancetype)initWithWindow:(UIWindow *)window richMediaStyle:(PWRichMediaStyle *)style {
    if (self = [super init]) {
        _barStyle = [UIApplication sharedApplication].statusBarStyle;
        _window = window;
        _richMediaStyle = style;
        self.edgesForExtendedLayout = UIRectEdgeBottom;
        UIInterfaceOrientationMask supportedOrientations = 0;
        if ([[[UIApplication sharedApplication] delegate] respondsToSelector:@selector(application:supportedInterfaceOrientationsForWindow:)]) {
            supportedOrientations = [[[UIApplication sharedApplication] delegate] application:[UIApplication sharedApplication] supportedInterfaceOrientationsForWindow:window];
        } else {
            supportedOrientations = [[UIApplication sharedApplication] supportedInterfaceOrientationsForWindow:window];
        }
        
        _supportedOrientations = supportedOrientations;
    }
    return self;
}

- (void)loadView {
    self.view = [[PWInteractionDisabledView alloc] initWithFrame:[UIScreen mainScreen].bounds];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    PWLoadingView *loadingView = nil;
    
    if (_richMediaStyle.loadingViewBlock) {
        loadingView = _richMediaStyle.loadingViewBlock();
    }
    
    if (!loadingView || ![loadingView isKindOfClass:[PWLoadingView class]]) {
        loadingView = [PWLoadingView new];
    }
    
    loadingView.frame = self.view.bounds;
    loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:loadingView];
    [loadingView.cancelLoadingButton addTarget:self action:@selector(closeController) forControlEvents:UIControlEventTouchUpInside];
    
    _loadingView = loadingView;
}

- (void)closeController {
    [_window setHidden:YES];
    _window = nil;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return _barStyle;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return _supportedOrientations;
}

- (BOOL)shouldAutorotate {
    return YES;
}

@end
#endif
