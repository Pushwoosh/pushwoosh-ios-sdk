//
//  PWIInboxStyle.m
//  PushwooshInboxUI
//
//  Created by Pushwoosh on 01/11/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWIInboxStyle.h"
#import "UIImage+PWITintColor.h"
#import "NSBundle+PWIHelper.h"

@interface PWIInboxStyleDefault : NSObject

@property (nonatomic) PWIInboxStyle *defaultStyle;

@end

@implementation PWIInboxStyleDefault

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

@end

@interface PWIInboxStyle ()

@property (nonatomic) NSDateFormatter *formatter;
@property (nonatomic) NSDateFormatter *timeFormatter;

@end

@implementation PWIInboxStyle

+ (instancetype)customStyleWithDefaultImageIcon:(UIImage *)icon textColor:(UIColor *)textColor accentColor:(UIColor *)accentColor font:(UIFont *)font {
    PWIInboxStyle *style = [self createDefaultStyle];
    [style setupTextColor:textColor accentColor:accentColor font:font];
    style.defaultImageIcon = icon;
    return style;
}

+ (instancetype)customStyleWithDefaultImageIcon:(UIImage *)icon textColor:(UIColor *)textColor accentColor:(UIColor *)accentColor font:(UIFont *)font dateFromatterBlock:(PWIDateFormatterBlock)dateFormatterBlock {
    PWIInboxStyle *style = [self customStyleWithDefaultImageIcon:icon textColor:textColor accentColor:accentColor font:font];
    style.dateFormatterBlock = dateFormatterBlock;
    return style;
}

- (void)setupTextColor:(UIColor *)color accentColor:(UIColor *)accentColor font:(UIFont *)font {
    _defaultFont = [font fontWithSize:UIFont.systemFontSize];
    _defaultTextColor = color;
    
    _accentColor = accentColor;
    _titleColor = color;
    _descriptionColor = [color colorWithAlphaComponent:0.85];
    _dateColor = [color colorWithAlphaComponent:0.85];
    _separatorColor = [color colorWithAlphaComponent:0.5];
    
    _titleFont = [font fontWithSize:UIFont.systemFontSize];
    _descriptionFont = [font fontWithSize:UIFont.systemFontSize];
    _dateFont = [font fontWithSize:UIFont.smallSystemFontSize];
    
    _listEmptyMessage = NSLocalizedString(@"There are currently no messages in Inbox.",);
    _listErrorMessage = NSLocalizedString(@"It seems something went wrong. Please try again later!",);
    
    _unreadImage = [UIImage imageNamed:@"unread" inBundle:[NSBundle pwi_bundleForClass:self.class] compatibleWithTraitCollection:nil];
    _listErrorImage = [UIImage imageNamed:@"errorMessage" inBundle:[NSBundle pwi_bundleForClass:self.class] compatibleWithTraitCollection:nil];
    _listEmptyImage = [UIImage imageNamed:@"noMessage" inBundle:[NSBundle pwi_bundleForClass:self.class] compatibleWithTraitCollection:nil];
    
    [self updateAccentColor];
}

- (void)setAccentColor:(UIColor *)accentColor {
    if (![_accentColor isEqual:accentColor]) {
        _accentColor = accentColor;
        [self updateAccentColor];
    }
}

- (void)setUnreadImage:(UIImage *)unreadImage {
    _unreadImage = unreadImage;
    [self updateAccentColor];
}

- (void)setListErrorImage:(UIImage *)listErrorImage {
    _listErrorImage = listErrorImage;
    [self updateAccentColor];
}

- (void)setListEmptyImage:(UIImage *)listEmptyImage {
    _listEmptyImage = listEmptyImage;
    [self updateAccentColor];
}

- (void)updateAccentColor {
    _unreadImage = [_unreadImage pwi_imageWithTintColor:_accentColor];
    _listErrorImage = [_listErrorImage pwi_imageWithTintColor:_accentColor];
    _listEmptyImage = [_listEmptyImage pwi_imageWithTintColor:_accentColor];
}

+ (void)setupDefaultStyle:(PWIInboxStyle *)style {
    [PWIInboxStyleDefault sharedInstance].defaultStyle = style;
}

+ (instancetype)defaultStyle {
    if ([PWIInboxStyleDefault sharedInstance].defaultStyle) {
        return [PWIInboxStyleDefault sharedInstance].defaultStyle;
    } else {
        PWIInboxStyle *style = [self createDefaultStyle];
        [PWIInboxStyleDefault sharedInstance].defaultStyle = style;
        return style;
    }
}

+ (instancetype)createDefaultStyle {
    PWIInboxStyle *style = [self new];
    style.backgroundColor = [UIApplication sharedApplication].keyWindow.rootViewController.view.backgroundColor ?: [UIColor whiteColor];
    UIColor *accentColor = [UIApplication sharedApplication].keyWindow.tintColor;
    if (!accentColor) {
        accentColor = [UIColor colorWithRed:9.0f / 255.0f green:105.f / 255.0 blue:150.f / 255.0 alpha:1.0];
    }
    [style setup];
    [style setupTextColor:[UIColor darkTextColor] accentColor:accentColor font:[UIFont systemFontOfSize:17]];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if ([UIFont respondsToSelector:@selector(systemFontOfSize:weight:)]) {
        style.titleFont = [UIFont systemFontOfSize:UIFont.systemFontSize weight:UIFontWeightMedium];
    }
#pragma clang diagnostic pop
    
    return style;
}

- (void)setup {
    _formatter = [[NSDateFormatter alloc] init];
    [_formatter setDateFormat:@"yyyy.MM.dd"];
    _timeFormatter = [NSDateFormatter new];
    _timeFormatter.timeStyle = NSDateFormatterShortStyle;
    
    __weak typeof(self) wself = self;
    [self setupDateFrommater:^NSString *(NSDate *date, NSObject *owner) {
        if ([[NSCalendar currentCalendar] isDateInToday:date]) {
            return [wself.timeFormatter stringFromDate:date];
        } else {
            return [wself.formatter stringFromDate:date];
        }
    }];
    
    _defaultImageIcon = [UIImage imageNamed:[NSBundle mainBundle].infoDictionary[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconName"]];
    if (!_defaultImageIcon) {
        _defaultImageIcon = [UIImage imageNamed:@"inbox_icon" inBundle:[NSBundle pwi_bundleForClass:self.class] compatibleWithTraitCollection:nil];
    }
}

- (void)setupDateFrommater:(PWIDateFormatterBlock)block {
    _dateFormatterBlock = [block copy];
}

@end
