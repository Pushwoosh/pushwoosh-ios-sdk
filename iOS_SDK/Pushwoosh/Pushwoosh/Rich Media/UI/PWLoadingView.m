//
//  PWLoadingView.m
//  Pushwoosh
//
//  Created by Fectum on 11/10/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//
#if TARGET_OS_IOS || TARGET_OS_WATCH

#import "PWRichMediaStyle.h"
#import "PWUtils.h"

@implementation PWLoadingView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        UIView *downloadIndicatorBackground = [self createDownloadIndicatorBackground];
        
        _activityIndicatorView = [self createDownloadIndicator];
        
        downloadIndicatorBackground.autoresizingMask = _activityIndicatorView.autoresizingMask = [self downloadAutoresizing];
        
        downloadIndicatorBackground.center = _activityIndicatorView.center = self.center;
        
        [self addSubview:downloadIndicatorBackground];
        [self addSubview:_activityIndicatorView];
        
        [_activityIndicatorView startAnimating];
        
        _cancelLoadingButton = [PWUtils webViewCloseButton];
        
        [self addSubview:_cancelLoadingButton];
    }
    
    return self;
}

- (UIView *)createDownloadIndicatorBackground {
    UIView *downloadIndicatorBackground = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 75, 75)];
    downloadIndicatorBackground.layer.cornerRadius = 8;
    downloadIndicatorBackground.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    return downloadIndicatorBackground;
}

- (UIActivityIndicatorView *)createDownloadIndicator {
    return [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
}

- (UIViewAutoresizing)downloadAutoresizing {
    UIViewAutoresizing downloadAutoresizing =
    UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleBottomMargin |
    UIViewAutoresizingFlexibleLeftMargin;
    return downloadAutoresizing;
}

@end
#endif
