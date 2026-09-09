#if TARGET_OS_IOS

//
//  PWModalWindow.m
//  Pushwoosh
//
//  Created by Andrew Kiselev on 10.2.23..
//  Copyright © 2023 Pushwoosh. All rights reserved.
//

#import "PWModalWindow.h"
#import "PWInteractionDisabledWindow.h"
#import "PWResource.h"
#import "PWModalWindowSettings.h"
#import "PWUtils.h"
#import "PWRichMedia+Internal.h"
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PWRichMediaManager.h>

@interface PWModalWindow ()

@property (nonatomic, strong) PWRichMediaView *richMediaView;
@property (nonatomic, strong) PWRichMedia *richMedia;
@property (nonatomic) PWRichMedia *richMediaQueue;
@property (nonatomic) PWWebClient *webClient;
@property (nonatomic) PWModalWindow *modalWindow;
@property (nonatomic, weak) PWModalWindow *presenter;
@property (nonatomic) PWModalWindowSettings *settings;
@property (nonatomic, strong) PWResource *currentResource;
@property (nonatomic) BOOL isDismissing;

- (void)presentWithEffectiveAnimation;
- (NSTimeInterval)effectiveAnimationDurationForResource:(PWResource *)resource fallback:(NSTimeInterval)fallback;

@end

@implementation PWModalWindow

static const NSTimeInterval kPWModalDefaultAnimationDuration = 0.3;

- (void)closeModalWindowAfter:(NSTimeInterval)interval {
    _settings.autoCloseInterval = interval;
}

- (void)presentModalWindow:(PWRichMedia *)richMedia modalWindow:(PWModalWindow *)modalWindow {
    UIWindow *window = [self keyWindow];
    _modalWindow = [[PWModalWindow alloc] initWithFrame:CGRectMake(0, 0, window.bounds.size.width, 0)];
    _modalWindow.presenter = self;
    [_modalWindow createModalWindowWith:richMedia.resource
                              richMedia:richMedia
                            modalWindow:_modalWindow
                                 window:window];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.clipsToBounds = YES;

    _settings = [PWModalWindowSettings sharedSettings];
}

#pragma mark - Configuration Priority Methods

- (ModalWindowPosition)effectiveModalWindowPositionForResource:(PWResource *)resource {
    [resource readConfig];

    if (resource.config && resource.position != PWModalWindowPositionDefault) {
        return resource.position;
    }
    return _settings.modalWindowPosition;
}

- (PresentModalWindowAnimation)effectivePresentAnimationForResource:(PWResource *)resource {
    [resource readConfig];

    if (resource.config && resource.presentAnimation != PWAnimationPresentUnset) {
        return resource.presentAnimation;
    }
    return _settings.presentAnimation;
}

- (DismissModalWindowAnimation)effectiveDismissAnimationForResource:(PWResource *)resource {
    [resource readConfig];

    if (resource.config && resource.dismissAnimation != PWAnimationDismissUnset) {
        return resource.dismissAnimation;
    }
    return _settings.dismissAnimation;
}

- (NSArray<NSNumber *> *)effectiveSwipeDirectionsForResource:(PWResource *)resource {
    [resource readConfig];

    if (resource.config && resource.swipeToDismiss.count > 0) {
        return resource.swipeToDismiss;
    }
    return _settings.dismissSwipeDirections;
}

- (NSTimeInterval)effectiveAnimationDurationForResource:(PWResource *)resource fallback:(NSTimeInterval)fallback {
    [resource readConfig];

    if (resource.config && resource.animationDuration > 0) {
        return resource.animationDuration;
    }
    if (_settings.animationDuration > 0) {
        return _settings.animationDuration;
    }
    return fallback;
}

#pragma mark - Modal Window Setup

- (void)createModalWindowWith:(PWResource *)resource
                    richMedia:(PWRichMedia *)richMedia
                  modalWindow:(PWModalWindow *)modalWindow
                       window:(UIWindow *)window {
    _currentResource = resource;

    modalWindow.translatesAutoresizingMaskIntoConstraints = NO;
    [window addSubview:modalWindow];

    if ([self shouldShowCloseButtonForResource:resource]) {
        [self setupCloseButtonForModalWindow:modalWindow inWindow:window];
    }

    [self setupModalWindowConstraintsInWindow:window];
    [modalWindow createModalWindow:resource modalWindow:richMedia];
}

- (BOOL)shouldShowCloseButtonForResource:(PWResource *)resource {
    ModalWindowPosition position = [self effectiveModalWindowPositionForResource:resource];

    return resource.closeButton &&
           (position == PWModalWindowPositionCenter ||
            position == PWModalWindowPositionDefault);
}

- (void)setupCloseButtonForModalWindow:(PWModalWindow *)modalWindow inWindow:(UIWindow *)window {
    _closeButton = [PWUtils webViewCloseButton];
    _closeButton.alpha = 0.0;
    [_closeButton addTarget:self action:@selector(closeModalWindowWithButton) forControlEvents:UIControlEventTouchUpInside];

    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [modalWindow.superview addSubview:_closeButton];
}

- (void)setupModalWindowConstraintsInWindow:(UIWindow *)window {
    UILayoutGuide *safe = window.safeAreaLayoutGuide;
    ModalWindowPosition effectivePosition = [self effectiveModalWindowPositionForResource:_currentResource];

    [NSLayoutConstraint activateConstraints:@[
        [self.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor]
    ]];

    switch (effectivePosition) {
        case PWModalWindowPositionTop:
            [NSLayoutConstraint activateConstraints:@[
                [self.topAnchor constraintEqualToAnchor:safe.topAnchor constant:15]
            ]];
            break;
        case PWModalWindowPositionBottom:
            [NSLayoutConstraint activateConstraints:@[
                [self.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-15]
            ]];
            break;
        case PWModalWindowPositionBottomSheet:
            [NSLayoutConstraint activateConstraints:@[
                [self.bottomAnchor constraintEqualToAnchor:window.bottomAnchor constant:0]
            ]];
            break;
        case PWModalWindowPositionFullScreen:
            [NSLayoutConstraint activateConstraints:@[
                [self.topAnchor constraintEqualToAnchor:window.topAnchor],
                [self.bottomAnchor constraintEqualToAnchor:window.bottomAnchor],
                [self.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
                [self.trailingAnchor constraintEqualToAnchor:window.trailingAnchor]
            ]];
            break;
        case PWModalWindowPositionCenter:
        case PWModalWindowPositionDefault:
            [self activateCenterConstraintsForModalWindow:safe];
            break;
        default:
            break;
    }
}

- (void)activateCenterConstraintsForModalWindow:(UILayoutGuide *)safe {
    if (_closeButton) {
        [NSLayoutConstraint activateConstraints:@[
            [_closeButton.bottomAnchor constraintEqualToAnchor:self.topAnchor constant:-5],
            [_closeButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:15],
            [_closeButton.widthAnchor constraintEqualToConstant:35],
            [_closeButton.heightAnchor constraintEqualToConstant:35],
            [self.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
            [self.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [self.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
            [self.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor]
        ]];
    }
}


- (UIWindow *)keyWindow {
    NSArray<UIWindow *> *windows = [[UIApplication sharedApplication] windows];
    for (UIWindow *window in windows) {
        if (window.isKeyWindow) {
            return window;
        }
    }
    return nil;
}

- (void)closeModalWindowWithButton {
    [self didCloseModalWindow:nil];
}

- (void)createModalWindow:(PWResource *)resource modalWindow:(PWRichMedia *)richMedia {
    [self.richMediaView removeFromSuperview];
    self.richMediaView = nil;

    self.richMedia = richMedia;
    _richMediaView = [[PWRichMediaView alloc] initWithFrame:self.bounds
                                                    payload:richMedia.pushPayload
                                                       code:(richMedia.resource.isRichMedia ? richMedia.content : @"")
                                                  inAppCode:(!richMedia.resource.isRichMedia ? richMedia.content : @"")];
    self.richMediaView.webClient.webView.scrollView.scrollEnabled = NO;
    self.richMediaView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.richMediaView.alpha = 0.0f;
    self.richMediaView.userInteractionEnabled = YES;
    self.richMediaView.exclusiveTouch = YES;

    if (!_richMedia.resource.locked) {
        __weak typeof(self) weakSelf = self;

        self.richMediaView.closeActionBlock = ^{
            [weakSelf didCloseModalWindow:nil];
        };

        self.richMediaView.contentSizeDidChangeBlock = ^{
            [weakSelf invalidateIntrinsicContentSize];
            [weakSelf.superview setNeedsLayout];
            [weakSelf.superview layoutIfNeeded];

            [weakSelf animateViewWithCompletion:nil];
        };

        [self addSubview:self.richMediaView];

        [self.richMediaView loadRichMedia:richMedia completion:^(NSError *error) {
            if (!error) {
                [weakSelf animateViewWithCompletion:^{
                    [weakSelf presentWithEffectiveAnimation];
                }];
            } else {
                if ([[[PWManagerBridge shared] richMediaManager].delegate respondsToSelector:@selector(richMediaManager:presentingDidFailForRichMedia:withError:)]) {
                    [[[PWManagerBridge shared] richMediaManager].delegate richMediaManager:[[PWManagerBridge shared] richMediaManager] presentingDidFailForRichMedia:weakSelf.richMedia withError:error];
                }
            }
        }];
    }
}

- (void)presentWithEffectiveAnimation {
    PresentModalWindowAnimation effectivePresent = [self effectivePresentAnimationForResource:self.currentResource];

    [self.superview layoutIfNeeded];

    if (effectivePresent == PWAnimationPresentNone) {
        self.transform = CGAffineTransformIdentity;
        self.closeButton.transform = CGAffineTransformIdentity;
        self.closeButton.alpha = 1.0f;
        self.richMediaView.alpha = 1.0f;
        [self handlePostAnimationTasks];
        return;
    }

    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGAffineTransform offscreen = CGAffineTransformIdentity;

    switch (effectivePresent) {
        case PWAnimationPresentSlideUp:
            offscreen = CGAffineTransformMakeTranslation(0, screenHeight);
            break;
        case PWAnimationPresentDropDown:
            offscreen = CGAffineTransformMakeTranslation(0, -screenHeight);
            break;
        case PWAnimationPresentSlideFromLeft:
            offscreen = CGAffineTransformMakeTranslation(-screenWidth, 0);
            break;
        case PWAnimationPresentSlideFromRight:
            offscreen = CGAffineTransformMakeTranslation(screenWidth, 0);
            break;
        default:
            break;
    }

    BOOL isFade = (effectivePresent == PWAnimationPresentFadeIn);

    self.transform = offscreen;
    self.closeButton.transform = offscreen;
    self.richMediaView.alpha = isFade ? 0.0f : 1.0f;
    self.closeButton.alpha = isFade ? 0.0f : 1.0f;

    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:[self effectiveAnimationDurationForResource:self.currentResource fallback:kPWModalDefaultAnimationDuration]
                                                                          dampingRatio:1.0
                                                                            animations:^{
        self.transform = CGAffineTransformIdentity;
        self.closeButton.transform = CGAffineTransformIdentity;
        self.richMediaView.alpha = 1.0f;
        self.closeButton.alpha = 1.0f;
    }];

    [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
        [self handlePostAnimationTasks];
    }];

    [animator startAnimation];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setCornerTypeForRichMedia:self.richMediaView];
}

- (void)setCornerTypeForRichMedia:(PWRichMediaView *)view {
    UIRectCorner corners = 0;

    if (_settings.cornerType & PWCornerTypeTopLeft) {
        corners |= UIRectCornerTopLeft;
    }
    if (_settings.cornerType & PWCornerTypeTopRight) {
        corners |= UIRectCornerTopRight;
    }
    if (_settings.cornerType & PWCornerTypeBottomLeft) {
        corners |= UIRectCornerBottomLeft;
    }
    if (_settings.cornerType & PWCornerTypeBottomRight) {
        corners |= UIRectCornerBottomRight;
    }

    if (corners == 0) {
        view.layer.mask = nil;
        return;
    }

    CGFloat radius = _settings.cornerRadius;
    [view layoutIfNeeded];

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:view.bounds
                                               byRoundingCorners:corners
                                                     cornerRadii:CGSizeMake(radius, radius)];

    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = path.CGPath;
    maskLayer.frame = view.bounds;

    view.layer.mask = maskLayer;
}

- (void)handlePostAnimationTasks {
    if (_isDismissing || !self.richMedia) {
        return;
    }

    if ([[[PWManagerBridge shared] richMediaManager].delegate respondsToSelector:@selector(richMediaManager:didPresentRichMedia:)]) {
        [[[PWManagerBridge shared] richMediaManager].delegate richMediaManager:[[PWManagerBridge shared] richMediaManager] didPresentRichMedia:self.richMedia];
    }

    if (_settings.autoCloseInterval > 0) {
        NSTimeInterval delayInSeconds = _settings.autoCloseInterval;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        __weak typeof(self) weakSelf = self;
        dispatch_after(popTime, dispatch_get_main_queue(), ^{
            [weakSelf didCloseModalWindow:nil];
        });
    }

    [self addSwipeDismissDirection];
    [self addHapticFeedbackToModalWindow];
}

- (void)addHapticFeedbackToModalWindow {
    if (_settings.hapticFeedbackType == PWHapticFeedbackNone) {
        return;
    }

    UIImpactFeedbackStyle feedbackStyle;

    switch (_settings.hapticFeedbackType) {
        case PWHapticFeedbackLight:
            feedbackStyle = UIImpactFeedbackStyleLight;
            break;
        case PWHapticFeedbackMedium:
            feedbackStyle = UIImpactFeedbackStyleMedium;
            break;
        case PWHapticFeedbackHard:
            feedbackStyle = UIImpactFeedbackStyleHeavy;
            break;
        default:
            feedbackStyle = UIImpactFeedbackStyleLight;
            break;
    }

    UIImpactFeedbackGenerator *feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:feedbackStyle];
    [feedbackGenerator prepare];
    [feedbackGenerator impactOccurred];
}

- (void)addSwipeDismissDirection {
    NSArray<NSNumber *> *directions = [self effectiveSwipeDirectionsForResource:_currentResource];
    if (directions.count == 0 || [directions containsObject:@(PWSwipeDismissNone)]) {
        return;
    }

    for (NSNumber *swipeNumber in directions) {
        DismissModalWindowAnimation swipeDismissDirection = [swipeNumber integerValue];
        UISwipeGestureRecognizerDirection direction;

        switch (swipeDismissDirection) {
            case PWSwipeDismissUp:
                direction = UISwipeGestureRecognizerDirectionUp;
                break;
            case PWSwipeDismissDown:
                direction = UISwipeGestureRecognizerDirectionDown;
                break;
            case PWSwipeDismissLeft:
                direction = UISwipeGestureRecognizerDirectionLeft;
                break;
            case PWSwipeDismissRight:
                direction = UISwipeGestureRecognizerDirectionRight;
                break;
            default:
                continue;
        }

        UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeHandler:)];
        gestureRecognizer.direction = direction;
        [self.richMediaView addGestureRecognizer:gestureRecognizer];
    }
}

- (void)swipeHandler:(UISwipeGestureRecognizer *)recognizer {
    [self didCloseModalWindow:recognizer];
}

- (void)didCloseModalWindow:(UISwipeGestureRecognizer *)recognizer {
    if (_isDismissing) {
        return;
    }
    _isDismissing = YES;

    [self.richMediaView loadRichMedia:nil completion:nil];

    if (recognizer) {
        DismissModalWindowAnimation swipeDismissDirection = [self animationDirectionForSwipeDirection:recognizer.direction];
        [self animateDismissModalWindow:swipeDismissDirection completion:nil];
    } else {
        DismissModalWindowAnimation effectiveDismiss = [self effectiveDismissAnimationForResource:_currentResource];
        [self animateDismissModalWindow:effectiveDismiss completion:nil];
    }
}

- (DismissModalWindowAnimation)animationDirectionForSwipeDirection:(UISwipeGestureRecognizerDirection)direction {
    switch (direction) {
        case UISwipeGestureRecognizerDirectionUp:
            return PWAnimationDismissSlideUp;
        case UISwipeGestureRecognizerDirectionDown:
            return PWAnimationDismissSlideDown;
        case UISwipeGestureRecognizerDirectionLeft:
            return PWAnimationDismissSlideLeft;
        case UISwipeGestureRecognizerDirectionRight:
            return PWAnimationDismissSlideRight;
        default:
            return PWAnimationDismissSlideDown;
    }
}

- (void)animateDismissModalWindow:(DismissModalWindowAnimation)direction completion:(dispatch_block_t)completion {
    _richMedia.resource.locked = NO;
    if (direction == PWAnimationCurveEaseInOut || direction == PWAnimationDismissDefault) {
        [self animateCurveEaseInOut:self.richMediaView completion:completion];
        return;
    }

    if (direction == PWAnimationDismissNone) {
        [self handleRichMediaViewClosure];
        if (completion) {
            completion();
        }
        return;
    }

    if (direction == PWAnimationDismissFadeOut) {
        [UIView animateWithDuration:[self effectiveAnimationDurationForResource:_currentResource fallback:kPWModalDefaultAnimationDuration] animations:^{
            self.richMediaView.alpha = 0.0f;
            self.closeButton.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [self handleRichMediaViewClosure];
            if (completion) {
                completion();
            }
        }];
        return;
    }

    [UIView animateWithDuration:[self effectiveAnimationDurationForResource:_currentResource fallback:kPWModalDefaultAnimationDuration] animations:^{
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGAffineTransform offscreen = CGAffineTransformIdentity;

        if (direction == PWAnimationDismissSlideUp) {
            offscreen = CGAffineTransformMakeTranslation(0, -screenHeight);
        } else if (direction == PWAnimationDismissSlideDown) {
            offscreen = CGAffineTransformMakeTranslation(0, screenHeight);
        } else if (direction == PWAnimationDismissSlideLeft) {
            offscreen = CGAffineTransformMakeTranslation(-screenWidth, 0);
        } else if (direction == PWAnimationDismissSlideRight) {
            offscreen = CGAffineTransformMakeTranslation(screenWidth, 0);
        }
        self.transform = offscreen;
        self.closeButton.transform = offscreen;
    } completion:^(BOOL finished) {
        [self handleRichMediaViewClosure];
        if (completion) {
            completion();
        }
    }];
}

- (void)animateViewWithCompletion:(dispatch_block_t)completion {
    if (_isDismissing) {
        return;
    }
    [self handleRichMediaViewClosure];
    if (completion) {
        completion();
    }
}

- (void)animateCurveEaseInOut:(UIView *)view completion:(dispatch_block_t)completion {
    [UIView animateWithDuration:[self effectiveAnimationDurationForResource:self.currentResource fallback:0.2]
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        if (!_closeButton) {
            view.transform = CGAffineTransformMakeScale(1.3, 1.3);
            view.alpha = 0.0;
        } else {
            view.transform = CGAffineTransformMakeScale(1.3, 1.3);
            view.alpha = 0.0;
            self.closeButton.transform = CGAffineTransformMakeScale(1.3, 1.3);
            self.closeButton.alpha = 0.0;
        }
    }
                     completion:^(BOOL finished) {
        [self handleRichMediaViewClosure];
        if (completion) {
            completion();
        }
    }];
}

- (void)handleRichMediaViewClosure {
    if (!self.richMedia) {
        return;
    }

    if (!self.richMediaView.richMedia) { // User closed the view
        [self.richMediaView removeFromSuperview];
        self.richMediaView = nil;

        if ([[[PWManagerBridge shared] richMediaManager].delegate respondsToSelector:@selector(richMediaManager:didCloseRichMedia:)]) {
            [[[PWManagerBridge shared] richMediaManager].delegate richMediaManager:[[PWManagerBridge shared] richMediaManager] didCloseRichMedia:self.richMedia];
        }

        if (_closeButton) {
            [_closeButton removeFromSuperview];
            _closeButton = nil;
        }

        [self removeFromSuperview];

        self.richMedia = nil;
        self.currentResource = nil;

        if (_presenter.modalWindow == self) {
            _presenter.modalWindow = nil;
        }
    }
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(self.bounds.size.width, self.richMediaView ? self.richMediaView.contentSize.height : 0.1);
}

@end

#endif
