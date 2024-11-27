//
//  PWIInboxAttachmentViewController.m
//  PushwooshInboxUI
//
//  Created by Nikolay Galizin on 31/05/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//
#import <UIKit/UIViewControllerTransitioning.h>
#import "PWIInboxAttachmentViewController.h"
#import "UIImageView+PWILoadImage.h"
#import "NSBundle+PWIHelper.h"
#import "PWIInboxStyle.h"

@interface PWIInboxAttachmentViewController () <UIViewControllerAnimatedTransitioning>

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic) PWIInboxStyle *style;

@end

@implementation PWIInboxAttachmentViewController

- (instancetype)initWithStyle:(PWIInboxStyle *)style {
    NSString *stringName = self.nibName;
    if (self = [super initWithNibName:stringName bundle:[NSBundle pwi_bundleForClass:self.class]]) {
        _style = style;
        self.modalPresentationCapturesStatusBarAppearance = YES;
    }
    return self;
}

- (NSString *)nibName {
    return @"PWIInboxAttachmentViewController";
}

- (void)loadView {
    [[NSBundle pwi_bundleForClass:self.class] loadNibNamed:self.nibName owner:self options:nil];
    if (!_style) {
        _style = [PWIInboxStyle defaultStyle];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return [self respondsToSelector:NSSelectorFromString(@"isModalInPresentation")] ? 3 : UIStatusBarStyleDefault;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [_imageView pwi_loadImageFromUrl:_attachmentUrl callback:nil];
    [self updateStyle:_style];
}

- (void)updateStyle:(PWIInboxStyle *)style {
    _style = style;
    self.view.tintColor = _style.accentColor;
    self.view.backgroundColor = _style.backgroundColor;
}

- (IBAction)imageViewTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (nullable id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController* )presenting sourceController:(UIViewController *)source {
    return self;
}

- (nullable id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    return self;
}

- (NSTimeInterval)transitionDuration:(nullable id <UIViewControllerContextTransitioning>)transitionContext {
    return 0.4;
}

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *toController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController *fromController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    UIView *fromView = fromController.view;
    UIView *toView = toController.view;
    if ([toController isKindOfClass:[UINavigationController class]]) {
        toController = ((UINavigationController *)toController).viewControllers.firstObject;
    }
    
    BOOL isPresenting = toController == self;
    
    if (isPresenting) {
        [transitionContext.containerView addSubview:toView];
    }
    
    self.view.frame = [transitionContext finalFrameForViewController:self];
    
    UIView *beginAnimationView = [_animationBeginView snapshotViewAfterScreenUpdates:YES];
    CGRect beginAnimationFrame = beginAnimationView.frame = [_animationBeginView convertRect:_animationBeginView.bounds toView:transitionContext.containerView];
    CGRect imageFrame = [_imageView convertRect:_imageView.bounds toView:transitionContext.containerView];
    CGFloat xScale = beginAnimationView.frame.size.width/_imageView.image.size.width;
    CGFloat yScale = beginAnimationView.frame.size.height/_imageView.image.size.height;
    
    CGFloat scale = 1;
    if (xScale > yScale) {
        scale = imageFrame.size.height / _imageView.image.size.height * _imageView.image.size.width / beginAnimationView.frame.size.width;
    } else {
        scale = imageFrame.size.width / _imageView.image.size.width * _imageView.image.size.height / beginAnimationView.frame.size.height;
    }
    
    if (isPresenting) {
        self.view.alpha = 0;
        [transitionContext.containerView addSubview:beginAnimationView];
        
        _imageView.transform = CGAffineTransformMakeScale(1/scale, 1/scale);
        _imageView.center = beginAnimationView.center;
        
        _animationBeginView.hidden = YES;
        
        [UIView animateWithDuration:0.4 delay:0. usingSpringWithDamping:45.71 initialSpringVelocity:0 options:0 animations:^{
            beginAnimationView.center = CGPointMake(transitionContext.containerView.frame.size.width/2, transitionContext.containerView.frame.size.height/2);
            beginAnimationView.transform = CGAffineTransformMakeScale(scale, scale);
            self.view.alpha = 1;
            beginAnimationView.alpha = 0;
            _imageView.transform = CGAffineTransformIdentity;
            _imageView.center = self.view.center;
        } completion:^(BOOL finished) {
            _animationBeginView.hidden = NO;
            [transitionContext completeTransition:finished];
            [beginAnimationView removeFromSuperview];
        }];
    } else {
        UIView *endAnimationView = [_imageView snapshotViewAfterScreenUpdates:YES];
        [transitionContext.containerView addSubview:endAnimationView];
        _imageView.hidden = YES;
        _animationBeginView.alpha = 0;

        [UIView animateWithDuration:0.4 delay:0. usingSpringWithDamping:45.71 initialSpringVelocity:0 options:0 animations:^{
            endAnimationView.transform = CGAffineTransformMakeScale(1/scale, 1/scale);
            endAnimationView.center = CGPointMake(beginAnimationFrame.origin.x + beginAnimationFrame.size.width/2, beginAnimationFrame.origin.y + beginAnimationFrame.size.height/2);
            endAnimationView.alpha = 0;
            self.view.alpha = 0;
            _animationBeginView.alpha = 1;
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:finished];
            [fromView removeFromSuperview];
        }];
    }
}

@end
