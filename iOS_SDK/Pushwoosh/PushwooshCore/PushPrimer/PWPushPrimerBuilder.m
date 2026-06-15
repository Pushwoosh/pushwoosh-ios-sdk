//
//  PWPushPrimerBuilder.m
//  PushwooshCore
//
//  Created by André Kis on 15.06.2026.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS

#import "PWPushPrimerBuilder.h"
#import "PWPushPrimerPresenter.h"

@interface PWPushPrimerBuilder ()

@property (nonatomic, strong) PWPushPrimerConfig *config;

@end

@implementation PWPushPrimerBuilder

@synthesize style = _style;
@synthesize position = _position;
@synthesize title = _title;
@synthesize message = _message;
@synthesize acceptButton = _acceptButton;
@synthesize declineButton = _declineButton;
@synthesize imageURL = _imageURL;
@synthesize image = _image;
@synthesize backgroundColor = _backgroundColor;
@synthesize backgroundGradient = _backgroundGradient;
@synthesize titleColor = _titleColor;
@synthesize messageColor = _messageColor;
@synthesize acceptButtonColor = _acceptButtonColor;
@synthesize acceptButtonTextColor = _acceptButtonTextColor;
@synthesize declineButtonColor = _declineButtonColor;
@synthesize declineButtonTextColor = _declineButtonTextColor;
@synthesize cornerRadius = _cornerRadius;
@synthesize buttonBorderColor = _buttonBorderColor;
@synthesize buttonCornerRadius = _buttonCornerRadius;
@synthesize fallbackToSettings = _fallbackToSettings;
@synthesize minInterval = _minInterval;

- (instancetype)init {
    if (self = [super init]) {
        _config = [PWPushPrimerConfig new];
        _config.style = PWPushPrimerStyleAlert;
        _config.position = PWPushPrimerPositionBottom;
        _config.fallbackToSettings = YES;
    }
    return self;
}

- (PWPushPrimerBuilder *(^)(PWPushPrimerStyle))style {
    return ^PWPushPrimerBuilder *(PWPushPrimerStyle style) {
        self.config.style = style;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(PWPushPrimerPosition))position {
    return ^PWPushPrimerBuilder *(PWPushPrimerPosition position) {
        self.config.position = position;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(NSString *))title {
    return ^PWPushPrimerBuilder *(NSString *title) {
        self.config.title = title;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(NSString *))message {
    return ^PWPushPrimerBuilder *(NSString *message) {
        self.config.message = message;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(NSString *))acceptButton {
    return ^PWPushPrimerBuilder *(NSString *title) {
        self.config.acceptButtonTitle = title;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(NSString *))declineButton {
    return ^PWPushPrimerBuilder *(NSString *title) {
        self.config.declineButtonTitle = title;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(NSString *))imageURL {
    return ^PWPushPrimerBuilder *(NSString *url) {
        self.config.imageURL = url;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(UIImage *))image {
    return ^PWPushPrimerBuilder *(UIImage *image) {
        self.config.image = image;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(UIColor *))backgroundColor {
    return ^PWPushPrimerBuilder *(UIColor *color) {
        self.config.backgroundColor = color;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(NSArray<UIColor *> *))backgroundGradient {
    return ^PWPushPrimerBuilder *(NSArray<UIColor *> *colors) {
        self.config.backgroundGradientColors = colors;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(UIColor *))titleColor {
    return ^PWPushPrimerBuilder *(UIColor *color) {
        self.config.titleColor = color;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(UIColor *))messageColor {
    return ^PWPushPrimerBuilder *(UIColor *color) {
        self.config.messageColor = color;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(UIColor *))acceptButtonColor {
    return ^PWPushPrimerBuilder *(UIColor *color) {
        self.config.acceptButtonColor = color;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(UIColor *))acceptButtonTextColor {
    return ^PWPushPrimerBuilder *(UIColor *color) {
        self.config.acceptButtonTextColor = color;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(UIColor *))declineButtonColor {
    return ^PWPushPrimerBuilder *(UIColor *color) {
        self.config.declineButtonColor = color;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(UIColor *))declineButtonTextColor {
    return ^PWPushPrimerBuilder *(UIColor *color) {
        self.config.declineButtonTextColor = color;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(CGFloat))cornerRadius {
    return ^PWPushPrimerBuilder *(CGFloat radius) {
        self.config.cornerRadius = radius;
        self.config.cornerRadiusSet = YES;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(UIColor *))buttonBorderColor {
    return ^PWPushPrimerBuilder *(UIColor *color) {
        self.config.buttonBorderColor = color;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(CGFloat))buttonCornerRadius {
    return ^PWPushPrimerBuilder *(CGFloat radius) {
        self.config.buttonCornerRadius = radius;
        self.config.buttonCornerRadiusSet = YES;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(BOOL))fallbackToSettings {
    return ^PWPushPrimerBuilder *(BOOL enabled) {
        self.config.fallbackToSettings = enabled;
        return self;
    };
}

- (PWPushPrimerBuilder *(^)(NSTimeInterval))minInterval {
    return ^PWPushPrimerBuilder *(NSTimeInterval seconds) {
        self.config.minInterval = seconds;
        return self;
    };
}

- (void)present {
    [self present:nil];
}

- (void)present:(PWPushPrimerCompletion)completion {
    PWPushPrimerPresenter *presenter = [PWPushPrimerPresenter new];
    [presenter presentWithConfig:self.config completion:completion];
}

@end

#endif
