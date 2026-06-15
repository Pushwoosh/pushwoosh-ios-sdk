//
//  PWPushPrimerPresenter.h
//  PushwooshCore
//
//  Created by André Kis on 15.06.2026.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <PushwooshCore/PWPushPrimerBuilder.h>

NS_ASSUME_NONNULL_BEGIN

/// Snapshot of a configured primer, handed from the builder to the presenter.
@interface PWPushPrimerConfig : NSObject

@property (nonatomic) PWPushPrimerStyle style;
@property (nonatomic) PWPushPrimerPosition position;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy, nullable) NSString *acceptButtonTitle;
@property (nonatomic, copy, nullable) NSString *declineButtonTitle;
@property (nonatomic, copy, nullable) NSString *imageURL;
@property (nonatomic, nullable) UIImage *image;
@property (nonatomic, nullable) UIColor *backgroundColor;
@property (nonatomic, copy, nullable) NSArray<UIColor *> *backgroundGradientColors;
@property (nonatomic, nullable) UIColor *titleColor;
@property (nonatomic, nullable) UIColor *messageColor;
@property (nonatomic, nullable) UIColor *acceptButtonColor;
@property (nonatomic, nullable) UIColor *acceptButtonTextColor;
@property (nonatomic, nullable) UIColor *declineButtonColor;
@property (nonatomic, nullable) UIColor *declineButtonTextColor;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) BOOL cornerRadiusSet;
@property (nonatomic, nullable) UIColor *buttonBorderColor;
@property (nonatomic) CGFloat buttonCornerRadius;
@property (nonatomic) BOOL buttonCornerRadiusSet;
@property (nonatomic) BOOL fallbackToSettings;
@property (nonatomic) NSTimeInterval minInterval;

@end

@interface PWPushPrimerPresenter : NSObject

/// Reads the current authorization status and presents (or suppresses) the primer.
/// Decision and UI are dispatched to the main thread. `completion` is invoked with the outcome.
- (void)presentWithConfig:(PWPushPrimerConfig *)config completion:(nullable PWPushPrimerCompletion)completion;

/// Reads the raw authorization status. Exposed as a seam for unit tests.
- (void)readAuthorizationStatusWithCompletion:(void (^)(UNAuthorizationStatus status))completion;

/// Performs the state-aware decision for a given status and config: shows UI, suppresses, or
/// redirects, then reports the outcome. Pure routing — no async status read. Exposed for tests.
- (void)handleStatus:(UNAuthorizationStatus)status
              config:(PWPushPrimerConfig *)config
          completion:(nullable PWPushPrimerCompletion)completion;

@end

NS_ASSUME_NONNULL_END

#endif
