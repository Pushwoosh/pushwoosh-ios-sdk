//
//  PWMessageViewController.m
//  PushNotificationManager
//
//  Created by Kaizer on 08/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWMessageViewController.h"
#import "PWPushManagerJSBridge.h"
#import "PWUtils.h"
#import "PWRichMedia+Internal.h"
#import "PWRichMediaView.h"

@interface PWMessageViewController () <NSWindowDelegate>

@property (nonatomic) PWRichMediaView *richMediaView;
@property (nonatomic, strong) NSProgressIndicator *activityIndicator;
@property (nonatomic) PWRichMedia *richMedia;
@property (nonatomic) void(^completion)(BOOL success);

@end

@implementation PWMessageViewController

static PWMessageViewController *PWMessageViewController_instance = nil;

+ (void)presentWithRichMedia:(PWRichMedia *)richMedia {
    [self presentWithRichMedia:richMedia completion:nil];
}

+ (void)presentWithRichMedia:(PWRichMedia *)richMedia completion:(void(^)(BOOL success))completion {
    BOOL shouldShow = YES;
    
    if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:shouldPresentRichMedia:)]) {
        shouldShow = [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager] shouldPresentRichMedia:richMedia];
    }
    
    if (!richMedia.resource.locked && shouldShow) {
        [PWMessageViewController_instance close];
        PWMessageViewController_instance = [[PWMessageViewController alloc] initWithRichMedia:richMedia completion:completion];
        [PWMessageViewController_instance showWindow:nil];
        PWLogDebug(@"%@", richMedia.resource.code);
    }
}

- (instancetype)initWithRichMedia:(PWRichMedia *)richMedia completion:(void (^)(BOOL success))completion {
    NSRect screenSize = [[NSScreen mainScreen] frame];
    CGSize size = CGSizeMake(414, 736);
    CGPoint origin = CGPointMake(screenSize.size.width / 2 - size.width / 2,
                                 screenSize.size.height / 2 - size.height / 2);
    NSRect windowRect = NSMakeRect(origin.x, origin.y, size.width, size.height);
    
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowRect styleMask:NSTitledWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask | NSClosableWindowMask backing:NSBackingStoreBuffered defer:false];
    
    if (self = [super initWithWindow:window]) {
        _richMedia = richMedia;
        _completion = completion;
        
        window.delegate = self;
        
        _activityIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect((windowRect.size.width - 20) / 2, (windowRect.size.height - 20) / 2, 20, 20)];
        [_activityIndicator setStyle:NSProgressIndicatorSpinningStyle];
        _activityIndicator.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin | NSViewMaxYMargin | NSViewMaxXMargin;
        [self.window.contentView addSubview:_activityIndicator];
        [_activityIndicator startAnimation:nil];
#if TARGET_OS_IOS
        _richMediaView = [[PWRichMediaView alloc] initWithFrame:CGRectMake(0, 0, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height) payload:nil code:nil inAppCode:nil];
#elif TARGET_OS_OSX
        _richMediaView = [[PWRichMediaView alloc] initWithFrame:CGRectMake(0, 0, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height) payload:nil code:nil inAppCode:nil];
#endif
        _richMediaView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self.window.contentView addSubview:_richMediaView];
        
        _richMediaView.alphaValue = .0;
        
        __weak typeof (self) wself = self;
        [_richMediaView loadRichMedia:_richMedia completion:^(NSError *error) {
            if (!error) {
                [wself didLoadRichMediaView];
            } else {
                [wself richMediaViewDidFailWithError:error];
            }
        }];
        
        _richMediaView.closeActionBlock = ^{
            [wself close];
        };
    }
    
	return self;
}

- (void)didLoadRichMediaView {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *_Nonnull context) {
        context.duration = .3;
        _richMediaView.animator.alphaValue = 1.;
        _activityIndicator.animator.alphaValue = .0;
    } completionHandler:^{
        _activityIndicator.hidden = YES;
        [_activityIndicator stopAnimation:nil];
    }];
    
    self.window.title = _richMediaView.webClient.webView.title;
    
    if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:didPresentRichMedia:)]) {
        [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager] didPresentRichMedia:_richMedia];
    }
}

- (void)richMediaViewDidFailWithError:(NSError *)error {
    [self close];
    
    if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:presentingDidFailForRichMedia:withError:)]) {
        [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager]
                                        presentingDidFailForRichMedia:_richMedia
                                                            withError:error ? : [PWUtils pushwooshError:@"No HTML content"]];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    PWMessageViewController_instance = nil;
    
    if ([[PWRichMediaManager sharedManager].delegate respondsToSelector:@selector(richMediaManager:didCloseRichMedia:)]) {
        [[PWRichMediaManager sharedManager].delegate richMediaManager:[PWRichMediaManager sharedManager] didCloseRichMedia:_richMedia];
    }
}

#pragma mark -

- (void)dealloc {
    _richMedia.resource.locked = NO;
}

@end
