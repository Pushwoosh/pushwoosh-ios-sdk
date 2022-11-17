//
//  PWLoadingViewController.m
//  Pushwoosh
//
//  Created by Victor Eysner on 05/12/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS || TARGET_OS_WATCH

#import "PWLoadingViewController.h"
#import "PWRichMediaManager.h"

@interface PWLoadingViewController ()

@property (nonatomic) NSTimer *timer;

@end

@implementation PWLoadingViewController

+ (instancetype)showLoading {
    UIWindow *presentedWindow = [self presentedWindow];
    PWLoadingViewController *viewController = [[self alloc] initWithWindow:presentedWindow richMediaStyle:[PWRichMediaManager sharedManager].richMediaStyle];
    [viewController presentInWindow:presentedWindow];
    return viewController;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.loadingView.cancelLoadingButton.hidden = YES;
}

- (void)closeController {
    [super closeController];
    
    if (_cancelBlock) {
        _cancelBlock();
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _timer = [NSTimer scheduledTimerWithTimeInterval:self.richMediaStyle.closeButtonPresentingDelay target:self selector:@selector(timerFiredAction) userInfo:nil repeats:NO];
}

- (void)timerFiredAction {
    self.loadingView.cancelLoadingButton.hidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopTimer];
}

- (void)stopTimer {
    if ([_timer isValid]) {
        [_timer invalidate];
        _timer = nil;
    }
}

@end
#endif
