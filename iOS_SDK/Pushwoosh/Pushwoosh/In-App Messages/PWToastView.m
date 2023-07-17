//
//  PWToastView.m
//  Pushwoosh
//
//  Created by Andrei Kiselev on 10.2.23..
//  Copyright © 2023 Pushwoosh. All rights reserved.
//

#import "PWToastView.h"
#import "PWInteractionDisabledWindow.h"
#import "PWRichMediaView.h"
#import "PWRichMedia+Internal.h"
#import "PWResource.h"

@interface PWToastView ()

@property (nonatomic) PWRichMediaView *richMediaView;
@property (nonatomic) PWRichMedia *richMedia;

@end

@implementation PWToastView

static NSTimeInterval timeInterval = 0;

+ (void)closeToastViewAfter:(NSTimeInterval)interval {
    timeInterval = interval;
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
}

- (void)createToastView:(PWResource *)resource position:(IAResourcePresentationStyle)position  {
    [_richMediaView removeFromSuperview];
    _richMediaView = nil;
    
    CGFloat yPositionInitialize = 1000.f;
    
    _richMediaView = [[PWRichMediaView alloc] initWithFrame:self.bounds payload:nil code:nil inAppCode:nil];
    _richMediaView.webClient.webView.scrollView.scrollEnabled = NO;
    _richMediaView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _richMediaView.alpha = 0.0f;
    _richMediaView.userInteractionEnabled = YES;
    _richMediaView.exclusiveTouch = YES;
    
    __weak typeof (self) wself = self;
    
    _richMediaView.closeActionBlock = ^{
        [wself didCloseToastView];
    };
    
    _richMediaView.contentSizeDidChangeBlock = ^{
        [wself animateViewWithCompletion:nil];
    };
    
    [self addSubview:_richMediaView];

    _richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:resource];
    
    __block CGRect frame = self.frame;
    
    [self.richMediaView loadRichMedia:_richMedia completion:^(NSError *error) {
        if (!error) {
            [wself animateViewWithCompletion:^{
                if (position == IAResourcePresentationTopBanner) {
                    wself.frame = CGRectOffset(wself.richMediaView.frame, 0.f, -yPositionInitialize);
                } else if (position == IAResourcePresentationBottomBanner || position == IAResourcePresentationCenter) {
                    wself.frame = CGRectOffset(wself.richMediaView.frame, 0.f, yPositionInitialize);
                }
                
                wself.richMediaView.alpha = 1.0;
                
                [UIView animateWithDuration:0.6
                                      delay:0.2
                     usingSpringWithDamping:0.7
                      initialSpringVelocity:1.0
                                    options:0 animations:^{
                    if (position == IAResourcePresentationTopBanner) {
                        frame.origin.y += yPositionInitialize;
                        wself.frame = frame;
                    } else if (position == IAResourcePresentationBottomBanner || position == IAResourcePresentationCenter) {
                        frame.origin.y -= yPositionInitialize;
                        wself.frame = frame;
                    }
                }
                                 completion:^(BOOL finished) {
                    
                    if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:didPresentRichMedia:)]) {
                        [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager] didPresentRichMedia:wself.richMedia];
                    }
                    
                    if (timeInterval > 0) {
                        NSTimeInterval delayInSeconds = timeInterval;
                        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                            [UIView animateWithDuration:0.3 animations:^{
                                [self hideToastViewWith:position];
                            } completion:^(BOOL finished) {
                                [self removeFromSuperview];
                                [self didCloseToastView];
                                
                                if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:didCloseRichMedia:)]) {
                                    [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager] didCloseRichMedia:self.richMedia];
                                }
                            }];
                        });
                    }
                    
                    [wself addGestureRecognizerWithViewPosition:position];
                }];
            }];
        } else {
            if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:presentingDidFailForRichMedia:withError:)]) {
                [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager] presentingDidFailForRichMedia:wself.richMedia withError:error];
            }
        }
    }];
}

- (void)addGestureRecognizerWithViewPosition:(IAResourcePresentationStyle)position {
    UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeHandler:)];

    if (position == IAResourcePresentationTopBanner) {
        [gestureRecognizer setDirection:(UISwipeGestureRecognizerDirectionUp)];
    } else if (position == IAResourcePresentationBottomBanner) {
        [gestureRecognizer setDirection:(UISwipeGestureRecognizerDirectionDown)];
    }
    [_richMediaView addGestureRecognizer:gestureRecognizer];
}

- (void)swipeHandler:(UISwipeGestureRecognizer *)recognizer {
    [UIView animateWithDuration:0.3 animations:^{
        if (recognizer.direction == UISwipeGestureRecognizerDirectionUp) {
            [self hideToastViewWith:IAResourcePresentationTopBanner];
        } else if (recognizer.direction == UISwipeGestureRecognizerDirectionDown) {
            [self hideToastViewWith:IAResourcePresentationBottomBanner];
        }
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        [self didCloseToastView];
    }];
}

- (void)hideToastViewWith:(IAResourcePresentationStyle)position {
    CGFloat hideAnimationPosition = 1000.f;
    CGRect frame = self.frame;
    
    if (position == IAResourcePresentationTopBanner) {
        frame.origin.y -= hideAnimationPosition;
        self.frame = frame;
    } else if (position == IAResourcePresentationBottomBanner || position == IAResourcePresentationCenter) {
        frame.origin.y += hideAnimationPosition;
        self.frame = frame;
    }
}

- (void)didCloseToastView {
    [_richMediaView loadRichMedia:nil completion:nil];
    
    [self animateViewWithCompletion:^{
        
    }];
}

- (void)animateViewWithCompletion:(dispatch_block_t)completion {
    [UIView animateWithDuration:0.3f
                     animations:^{
        [self invalidateIntrinsicContentSize];
        [self.superview setNeedsLayout];
        [self.superview layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (!_richMediaView.richMedia) { //user closed view
            [_richMediaView removeFromSuperview];
            _richMediaView = nil;
            
            if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:didCloseRichMedia:)]) {
                [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager] didCloseRichMedia:self.richMedia];
            }
        }
        
        if (completion) {
            completion();
        }
    }];
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(self.bounds.size.width, _richMediaView ? _richMediaView.contentSize.height : 0.1);
}

@end
