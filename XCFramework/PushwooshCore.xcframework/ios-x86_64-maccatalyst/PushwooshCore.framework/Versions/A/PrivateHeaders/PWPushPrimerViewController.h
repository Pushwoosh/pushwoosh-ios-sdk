//
//  PWPushPrimerViewController.h
//  PushwooshCore
//
//  Created by André Kis on 15.06.2026.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS

#import <UIKit/UIKit.h>
#import <PushwooshCore/PWPushPrimerPresenter.h>

NS_ASSUME_NONNULL_BEGIN

/// Custom half-screen sheet view controller for `PWPushPrimerStyleSheet`.
@interface PWPushPrimerViewController : UIViewController

- (instancetype)initWithConfig:(PWPushPrimerConfig *)config
                      onAccept:(void (^)(void))onAccept
                     onDecline:(void (^)(void))onDecline;

@end

NS_ASSUME_NONNULL_END

#endif
