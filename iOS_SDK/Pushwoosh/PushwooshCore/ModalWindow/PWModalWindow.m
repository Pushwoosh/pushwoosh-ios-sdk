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
@property (nonatomic) PWModalWindowSettings *settings;
@property (nonatomic, strong) PWResource *currentResource;

@end

@implementation PWModalWindow

static NSTimeInterval timeInterval = 0;

- (void)closeModalWindowAfter:(NSTimeInterval)interval {
    timeInterval = interval;
}

- (void)presentModalWindow:(PWRichMedia *)richMedia modalWindow:(PWModalWindow *)modalWindow {
    UIWindow *window = [self keyWindow];
    _modalWindow = [[PWModalWindow alloc] initWithFrame:CGRectMake(0, 0, window.bounds.size.width, 0)];
    [self createModalWindowWith:richMedia.resource
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
    
    if (resource.config && resource.presentAnimation != PWAnimationPresentNone) {
        return resource.presentAnimation;
    }
    return _settings.presentAnimation;
}

- (DismissModalWindowAnimation)effectiveDismissAnimationForResource:(PWResource *)resource {
    [resource readConfig];
    
    if (resource.config && resource.dismissAnimation != PWAnimationDismissDefault) {
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

#pragma mark - Modal Window Setup

- (void)createModalWindowWith:(PWResource *)resource
                    richMedia:(PWRichMedia *)richMedia
                  modalWindow:(PWModalWindow *)modalWindow
                       window:(UIWindow *)window {
    _modalWindow = modalWindow;
    _currentResource = resource;
    
    _modalWindow.translatesAutoresizingMaskIntoConstraints = NO;
    [window addSubview:_modalWindow];
    
    if ([self shouldShowCloseButtonForResource:resource]) {
        [self setupCloseButtonForModalWindow:_modalWindow inWindow:window];
    }

    [self setupModalWindowConstraintsInWindow:window];
    [_modalWindow createModalWindow:resource modalWindow:richMedia];
}

- (BOOL)shouldShowCloseButtonForResource:(PWResource *)resource {
    ModalWindowPosition position = [self effectiveModalWindowPositionForResource:resource];
    PresentModalWindowAnimation presentAnim = [self effectivePresentAnimationForResource:resource];
    DismissModalWindowAnimation dismissAnim = [self effectiveDismissAnimationForResource:resource];
    
    return resource.closeButton &&
           (position == PWModalWindowPositionCenter ||
            position == PWModalWindowPositionDefault) &&
           presentAnim == PWAnimationPresentFromBottom &&
           (dismissAnim == PWAnimationCurveEaseInOut ||
            dismissAnim == PWAnimationDismissDefault);
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
        [_modalWindow.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [_modalWindow.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor]
    ]];
    
    switch (effectivePosition) {
        case PWModalWindowPositionTop:
            [NSLayoutConstraint activateConstraints:@[
                [_modalWindow.topAnchor constraintEqualToAnchor:safe.topAnchor constant:15]
            ]];
            break;
        case PWModalWindowPositionBottom:
            [NSLayoutConstraint activateConstraints:@[
                [_modalWindow.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-15]
            ]];
            break;
        case PWModalWindowPositionBottomSheet:
            [NSLayoutConstraint activateConstraints:@[
                [_modalWindow.bottomAnchor constraintEqualToAnchor:window.bottomAnchor constant:0]
            ]];
            break;
        case PWModalWindowPositionFullScreen:
            [NSLayoutConstraint activateConstraints:@[
                [_modalWindow.topAnchor constraintEqualToAnchor:window.topAnchor],
                [_modalWindow.bottomAnchor constraintEqualToAnchor:window.bottomAnchor],
                [_modalWindow.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
                [_modalWindow.trailingAnchor constraintEqualToAnchor:window.trailingAnchor]
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
            [_closeButton.bottomAnchor constraintEqualToAnchor:_modalWindow.topAnchor constant:-5],
            [_closeButton.leadingAnchor constraintEqualToAnchor:_modalWindow.leadingAnchor constant:15],
            [_closeButton.widthAnchor constraintEqualToConstant:35],
            [_closeButton.heightAnchor constraintEqualToConstant:35],
            [_modalWindow.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
            [_modalWindow.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [_modalWindow.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
            [_modalWindow.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor]
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
    
    CGFloat yPositionInitialize = 2000;
    CGFloat xPositionInitialize = 2000;
    CGFloat safeAreaGap = 15.0;

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
        
    BOOL shouldShow = YES;
    
    if ([[[PWManagerBridge shared] richMediaManager].delegate respondsToSelector:@selector(richMediaManager:shouldPresentRichMedia:)]) {
        shouldShow = [[[PWManagerBridge shared] richMediaManager].delegate richMediaManager:[[PWManagerBridge shared] richMediaManager] shouldPresentRichMedia:_richMedia];
    }
    
    if (!_richMedia.resource.locked && shouldShow) {
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
                
        __block CGRect frame = self.frame;
        
        [self.richMediaView loadRichMedia:richMedia completion:^(NSError *error) {
            if (!error) {
                [weakSelf animateViewWithCompletion:^{
                    weakSelf.richMediaView.alpha = 1.0f;
                    weakSelf.modalWindow.closeButton.alpha = 1.0f;
                    
                    frame.origin.y = ([UIScreen mainScreen].bounds.size.height - weakSelf.richMediaView.frame.size.height) / 2;

                    PresentModalWindowAnimation effectivePresent = [weakSelf effectivePresentAnimationForResource:weakSelf.currentResource];
                    ModalWindowPosition effectivePosition = [weakSelf effectiveModalWindowPositionForResource:weakSelf.currentResource];

                    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:0.9
                                                                                          dampingRatio:1.0
                                                                                            animations:^{

                        switch (effectivePresent) {
                            case PWAnimationPresentFromTop:
                                frame.origin.y += yPositionInitialize;
                                weakSelf.frame = frame;
                                break;
                            case PWAnimationPresentFromBottom:
                                frame.origin.y -= yPositionInitialize;
                                weakSelf.frame = frame;
                                CGRect closeFrame = weakSelf.closeButton.frame;
                                closeFrame.origin.y -= yPositionInitialize;
                                weakSelf.closeButton.frame = closeFrame;
                                break;
                            case PWAnimationPresentFromLeft:
                            case PWAnimationPresentFromRight:
                                frame.origin.y = [self yPositionForModalWindow:effectivePosition safeAreaGap:safeAreaGap];
                                frame.origin.x += (effectivePresent == PWAnimationPresentFromLeft) ? xPositionInitialize : -xPositionInitialize;
                                weakSelf.frame = frame;
                                break;
                            default:
                                break;
                        }
                    }];
                    
                    [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
                        [weakSelf handlePostAnimationTasks];
                    }];
                    
                    [animator startAnimation];
                }];
            } else {
                if ([[[PWManagerBridge shared] richMediaManager].delegate respondsToSelector:@selector(richMediaManager:presentingDidFailForRichMedia:withError:)]) {
                    [[[PWManagerBridge shared] richMediaManager].delegate richMediaManager:[[PWManagerBridge shared] richMediaManager] presentingDidFailForRichMedia:weakSelf.richMedia withError:error];
                }
            }
        }];
    }
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

- (CGFloat)yPositionForModalWindow:(ModalWindowPosition)position safeAreaGap:(CGFloat)safeAreaGap {
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    if (position == PWModalWindowPositionBottom) {
        return screenHeight - self.richMediaView.frame.size.height - safeAreaGap;
    } else if (position == PWModalWindowPositionTop) {
        CGFloat safeAreaHeight = [UIApplication sharedApplication].windows.firstObject.safeAreaInsets.top;
        return safeAreaHeight + safeAreaGap;
    } else {
        return ([UIScreen mainScreen].bounds.size.height - self.richMediaView.frame.size.height) / 2;
    }
}

- (void)bottomPositionY:(CGRect)frame {
    CGFloat safeAreaBottom = 20.0;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    frame.origin.y = screenHeight - self.richMediaView.frame.size.height - safeAreaBottom;
}

- (void)handlePostAnimationTasks {
    if ([[[PWManagerBridge shared] richMediaManager].delegate respondsToSelector:@selector(richMediaManager:didPresentRichMedia:)]) {
        [[[PWManagerBridge shared] richMediaManager].delegate richMediaManager:[[PWManagerBridge shared] richMediaManager] didPresentRichMedia:self.richMedia];
    }
    
    if (timeInterval > 0) {
        NSTimeInterval delayInSeconds = timeInterval;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^{
            [self didCloseModalWindow:nil];
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
    [self.richMediaView loadRichMedia:nil completion:nil];
    
    if ([self shouldDismissModalWindow]) {
        DismissModalWindowAnimation effectiveDismiss = [self effectiveDismissAnimationForResource:_currentResource];
        [self animateDismissModalWindow:effectiveDismiss completion:nil];
        return;
    }
    
    DismissModalWindowAnimation swipeDismissDirection = [self animationDirectionForSwipeDirection:recognizer.direction];
    
    if (swipeDismissDirection != PWSwipeDismissNone) {
        [self animateDismissModalWindow:swipeDismissDirection completion:nil];
    }
}

- (BOOL)shouldDismissModalWindow {
    NSArray<NSNumber *> *directions = [self effectiveSwipeDirectionsForResource:_currentResource];
    return directions.count == 0 || [directions containsObject:@(PWSwipeDismissNone)];
}

- (DismissModalWindowAnimation)animationDirectionForSwipeDirection:(UISwipeGestureRecognizerDirection)direction {
    switch (direction) {
        case UISwipeGestureRecognizerDirectionUp:
            return PWAnimationDismissUp;
        case UISwipeGestureRecognizerDirectionDown:
            return PWAnimationDismissDown;
        case UISwipeGestureRecognizerDirectionLeft:
            return PWAnimationDismissLeft;
        case UISwipeGestureRecognizerDirectionRight:
            return PWAnimationDismissRight;
        default:
            return PWAnimationDismissDown;
    }
}

- (void)closeWithoutAnimation {
    [self handleRichMediaViewClosure];
}

- (void)animateDismissModalWindow:(DismissModalWindowAnimation)direction completion:(dispatch_block_t)completion {
    _richMedia.resource.locked = NO;
    if (direction == PWAnimationCurveEaseInOut || direction == PWAnimationDismissDefault) {
        [self animateCurveEaseInOut:self.richMediaView completion:nil];
        return;
    }
    
    [UIView animateWithDuration:0.5 animations:^{
        CGFloat dismissAnimationPosition = 1000.0f;
        CGRect frame = self.frame;
        
        if (direction == PWAnimationDismissUp) {
            frame.origin.y -= dismissAnimationPosition;
        } else if (direction == PWAnimationDismissDown) {
            frame.origin.y += dismissAnimationPosition;
        } else if (direction == PWAnimationDismissLeft) {
            frame.origin.x -= dismissAnimationPosition;
        } else if (direction == PWAnimationDismissRight) {
            frame.origin.x += dismissAnimationPosition;
        }
        self.frame = frame;
    } completion:^(BOOL finished) {
        [self handleRichMediaViewClosure];
        if (completion) {
            completion();
        }
    }];
}

- (void)animateViewWithCompletion:(dispatch_block_t)completion {
    [self handleRichMediaViewClosure];
    if (completion) {
        completion();
    }
}

- (void)animateCurveEaseInOut:(UIView *)view completion:(dispatch_block_t)completion {
    [UIView animateWithDuration:0.2
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
        if (_closeButton) {
            [view setHidden:YES];
            [view removeFromSuperview];
            _modalWindow = nil;
            [_closeButton setHidden:YES];
            [_closeButton removeFromSuperview];
            _closeButton = nil;
        }
        if (completion) {
            completion();
        }
    }];
}

- (void)handleRichMediaViewClosure {
    if (!self.richMediaView.richMedia) { // User closed the view
        [self.richMediaView removeFromSuperview];
        self.richMediaView = nil;
        
        if ([[[PWManagerBridge shared] richMediaManager].delegate respondsToSelector:@selector(richMediaManager:didCloseRichMedia:)]) {
            [[[PWManagerBridge shared] richMediaManager].delegate richMediaManager:[[PWManagerBridge shared] richMediaManager] didCloseRichMedia:self.richMedia];
        }
        
        [self removeFromSuperview];
    }
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(self.bounds.size.width, self.richMediaView ? self.richMediaView.contentSize.height : 0.1);
}

@end

#endif
