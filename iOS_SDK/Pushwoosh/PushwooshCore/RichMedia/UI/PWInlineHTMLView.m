//
//  PWInlineHTMLView.m
//  PushwooshCore
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS
#import "PWInlineHTMLView.h"
#import "PWRichMediaView.h"

@interface PWInlineHTMLView ()

@property (nonatomic, strong) PWRichMediaView *richMediaView;

@end

@implementation PWInlineHTMLView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _richMediaView = [[PWRichMediaView alloc] initWithFrame:self.bounds payload:nil code:nil inAppCode:nil];
        _richMediaView.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
        _richMediaView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _richMediaView.webClient.webView.scrollView.scrollEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        [self addSubview:_richMediaView];

        __weak PWInlineHTMLView *weakSelf = self;
        _richMediaView.closeActionBlock = ^{
            if (weakSelf.closeInApp) {
                weakSelf.closeInApp();
            }
        };
        _richMediaView.webClient.closingActionBlock = ^{
            if (weakSelf.closingActionDidRun) {
                weakSelf.closingActionDidRun();
            }
        };
        _richMediaView.webClient.shouldPostEventBlock = ^BOOL{
            BOOL (^shouldPostEvent)(void) = weakSelf.shouldPostEvent;
            return shouldPostEvent == nil || shouldPostEvent();
        };
    }
    return self;
}

- (WKWebView *)webView {
    return _richMediaView.webClient.webView;
}

- (void)loadHTMLString:(NSString *)html {
    [_richMediaView loadHTMLString:html completion:nil];
}

@end
#endif
