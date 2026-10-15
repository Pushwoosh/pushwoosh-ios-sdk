//
//  PWActionButton.h
//  PushwooshCore
//
//  Created by André Kis on 08.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// What a tapped button does. The wire spellings are the PWActionButtonActionValue… constants below.
typedef NS_ENUM(NSInteger, PWActionButtonAction) {
    PWActionButtonActionOpen,
    PWActionButtonActionUrl,
    PWActionButtonActionDeeplink,
    PWActionButtonActionCustom
};

/// The whole wire contract of the feature lives here, so the backend side of it (DEV-926) can be
/// renamed in one file.
FOUNDATION_EXPORT NSString * const PWActionButtonsPayloadKey;
FOUNDATION_EXPORT NSString * const PWActionButtonFieldId;
FOUNDATION_EXPORT NSString * const PWActionButtonFieldLabel;
FOUNDATION_EXPORT NSString * const PWActionButtonFieldAction;
FOUNDATION_EXPORT NSString * const PWActionButtonFieldUrl;
FOUNDATION_EXPORT NSString * const PWActionButtonFieldStyle;
FOUNDATION_EXPORT NSString * const PWActionButtonActionValueOpen;
FOUNDATION_EXPORT NSString * const PWActionButtonActionValueUrl;
FOUNDATION_EXPORT NSString * const PWActionButtonActionValueDeeplink;
FOUNDATION_EXPORT NSString * const PWActionButtonActionValueCustom;
FOUNDATION_EXPORT NSString * const PWActionButtonStyleValueDestructive;

/// Field the open statistics names the tapped button in.
FOUNDATION_EXPORT NSString * const PWActionButtonStatField;

/// Key the tapped action identifier travels under in the payload the SDK hands on after a tap.
FOUNDATION_EXPORT NSString * const PWActionIdentifierKey;

/// Prefix of the notification categories this SDK builds out of pw_buttons. Categories without it
/// belong to the application or to the Control Panel and are never touched.
FOUNDATION_EXPORT NSString * const PWActionButtonsCategoryPrefix;

/// How many buttons one push may show.
FOUNDATION_EXPORT const NSUInteger PWActionButtonsLimit;

/// How many pw_ categories stay registered on the device.
FOUNDATION_EXPORT const NSUInteger PWActionButtonsCategoryLimit;

/// One button of a push, already validated. Built only by PWActionButtonsParser.
@interface PWActionButton : NSObject

@property (nonatomic, readonly, copy) NSString *identifier;

/// Shown exactly as it arrived: the backend sends it already translated.
@property (nonatomic, readonly, copy) NSString *label;

@property (nonatomic, readonly) PWActionButtonAction action;

/// Set for PWActionButtonActionUrl and PWActionButtonActionDeeplink, nil for the other actions.
@property (nonatomic, readonly, copy, nullable) NSString *url;

@property (nonatomic, readonly) BOOL destructive;

/// NO for PWActionButtonActionCustom, YES for every other action.
@property (nonatomic, readonly) BOOL opensApplication;

- (instancetype)initWithIdentifier:(NSString *)identifier
                             label:(NSString *)label
                            action:(PWActionButtonAction)action
                               url:(nullable NSString *)url
                       destructive:(BOOL)destructive NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
