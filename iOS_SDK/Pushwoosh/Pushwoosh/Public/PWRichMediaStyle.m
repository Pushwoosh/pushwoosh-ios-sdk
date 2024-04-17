//
//  PWInAppStyle.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2018
//

#import "PWRichMediaStyle.h"

NSTimeInterval const PWRichMediaStyleDefaultAnimationDuration = 0.3f;

#if TARGET_OS_IOS
void PWRichMediaStyleRunAnimation(dispatch_block_t animationBlock, dispatch_block_t completion) {
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [UIView animateWithDuration:PWRichMediaStyleDefaultAnimationDuration
                     animations:animationBlock
                     completion:^(BOOL finished) {
                         [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                         
                         if (completion) {
                             completion();
                         }
                     }
     ];
}
#endif

@implementation PWRichMediaStyle

- (instancetype)init {
    if (self = [super init]) {
#if TARGET_OS_IOS
        _backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.3];
        _closeButtonPresentingDelay = 0.5f;
        _animationDelegate = [PWRichMediaStyleSlideBottomAnimation new];
        _shouldHideStatusBar = YES;
#endif
    }
    return self;
}

@end


@implementation PWRichMediaStyleSlideTopAnimation

#if TARGET_OS_IOS
- (void)runPresentingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion {
    contentView.transform = CGAffineTransformMakeTranslation(0, -parentView.bounds.size.height);
    PWRichMediaStyleRunAnimation(^{contentView.transform = CGAffineTransformIdentity;}, completion);
}

- (void)runDismissingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion {
    PWRichMediaStyleRunAnimation(^{contentView.transform = CGAffineTransformMakeTranslation(0, -parentView.bounds.size.height);}, completion);
}
#endif

@end


@implementation PWRichMediaStyleSlideBottomAnimation

#if TARGET_OS_IOS
- (void)runPresentingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion {
    contentView.transform = CGAffineTransformMakeTranslation(0, parentView.bounds.size.height);
    PWRichMediaStyleRunAnimation(^{contentView.transform = CGAffineTransformIdentity;}, completion);
}

- (void)runDismissingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion {
    PWRichMediaStyleRunAnimation(^{contentView.transform = CGAffineTransformMakeTranslation(0, parentView.bounds.size.height);}, completion);
}
#endif

@end


@implementation PWRichMediaStyleSlideLeftAnimation

#if TARGET_OS_IOS
- (void)runPresentingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion {
    contentView.transform = CGAffineTransformMakeTranslation(-parentView.bounds.size.width, 0);
    PWRichMediaStyleRunAnimation(^{contentView.transform = CGAffineTransformIdentity;}, completion);
}

- (void)runDismissingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion {
    PWRichMediaStyleRunAnimation(^{contentView.transform = CGAffineTransformMakeTranslation(-parentView.bounds.size.width, 0);}, completion);
}
#endif

@end


@implementation PWRichMediaStyleSlideRightAnimation

#if TARGET_OS_IOS
- (void)runPresentingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion {
    contentView.transform = CGAffineTransformMakeTranslation(parentView.bounds.size.width, 0);
    PWRichMediaStyleRunAnimation(^{contentView.transform = CGAffineTransformIdentity;}, completion);
}

- (void)runDismissingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion {
    PWRichMediaStyleRunAnimation(^{contentView.transform = CGAffineTransformMakeTranslation(parentView.bounds.size.width, 0);}, completion);
}
#endif

@end


@implementation PWRichMediaStyleCrossFadeAnimation

#if TARGET_OS_IOS
- (void)runPresentingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion {
    contentView.alpha = 0.0f;
    PWRichMediaStyleRunAnimation(^{contentView.alpha = 1.0f;}, completion);
}

- (void)runDismissingAnimationWithContentView:(UIView *)contentView parentView:(UIView *)parentView completion:(dispatch_block_t)completion {
    PWRichMediaStyleRunAnimation(^{contentView.alpha = 0.0f;}, completion);
}
#endif

@end
