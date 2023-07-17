//
//  PWInlineInAppView.m
//  Pushwoosh
//
//  Created by Fectum on 22/10/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//


#import "PWInlineInAppView.h"
#import "PWRichMediaView.h"
#import "PWInAppMessagesManager.h"
#import "PWInAppManager+Internal.h"
#import "PWWebClient.h"
#import "PWRichMedia+Internal.h"

#define kInlineInAppEvent @"inlineInApp"

@interface PWInlineInAppView()

@property(nonatomic) PWRichMediaView *richMediaView;

@end

@implementation PWInlineInAppView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.clipsToBounds = YES;
}

- (void)setIdentifier:(NSString *)identifier {
    BOOL theSameIdentifier = [identifier isEqualToString:_identifier];
    
    _identifier = identifier;
    
    if (identifier && !theSameIdentifier) {
        [self postEvent];
    }
}

- (void)createRichMediaView {
    [_richMediaView removeFromSuperview];
    
    _richMediaView = [[PWRichMediaView alloc] initWithFrame:self.bounds payload:nil code:nil inAppCode:nil];
    _richMediaView.webClient.webView.scrollView.scrollEnabled = NO;
    _richMediaView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _richMediaView.alpha = 0.0f;
    
    __weak typeof (self) wself = self;
    
    _richMediaView.closeActionBlock = ^{
        [wself didCloseRichMediaView];
    };
    
    _richMediaView.contentSizeDidChangeBlock = ^{
        [wself animateViewWithCompletion:nil];
    };
    
    [self addSubview:_richMediaView];
}

- (void)postEvent {
    __weak typeof (self) wself = self;
    [[PWInAppManager sharedManager].inAppMessagesManager postEventInternal:kInlineInAppEvent
                                                            withAttributes:@{@"identifier" : _identifier}
                                                             isInlineInApp:YES
                                                                completion:^(PWResource *resource, NSError *error) {
                                                                    if (!error) {
                                                                        [wself createRichMediaView];
                                                                        
                                                                        PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:resource];
                                                                        
                                                                        [wself.richMediaView loadRichMedia:richMedia completion:^(NSError *error) {
                                                                            if (!error) {
                                                                                [wself animateViewWithCompletion:^{
                                                                                    if ([_delegate respondsToSelector:@selector(inlineInAppDidLoadInView:)]) {
                                                                                        [_delegate inlineInAppDidLoadInView:self];
                                                                                    }
                                                                                }];
                                                                            }
                                                                        }];
                                                                    }
                                                                }];
}

- (void)didCloseRichMediaView {
    [_richMediaView loadRichMedia:nil completion:nil];
    
    [self animateViewWithCompletion:^{
        if ([_delegate respondsToSelector:@selector(didCloseInlineInAppView:)]) {
            [_delegate didCloseInlineInAppView:self];
        }
    }];
}

- (void)animateViewWithCompletion:(dispatch_block_t)completion {
    [UIView animateWithDuration:0.3f
                     animations:^{
                         _richMediaView.alpha = _richMediaView.richMedia ? 1.0f : 0.0f;
                         [self invalidateIntrinsicContentSize];
                         [self.superview setNeedsLayout];
                         [self.superview layoutIfNeeded];
                     } completion:^(BOOL finished) {
                         if (!_richMediaView.richMedia) { //user closed view
                             [_richMediaView removeFromSuperview];
                             _richMediaView = nil;
                         }
                         
                         if ([_delegate respondsToSelector:@selector(didChangeSizeOfInlineInAppView:)]) {
                             [_delegate didChangeSizeOfInlineInAppView:self];
                         }
                         
                         if (completion) {
                             completion();
                         }
                     }];
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(self.bounds.size.width, _richMediaView ? _richMediaView.contentSize.height : 1);
}

@end
