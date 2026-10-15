//
//  PWActionButtonsRegistrar.h
//  PushwooshCore
//
//  Created by André Kis on 08.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS

#import <UserNotifications/UserNotifications.h>

#import <PushwooshCore/PWActionButton.h>

NS_ASSUME_NONNULL_BEGIN

/// Turns the buttons of a push into an iOS notification category and registers it, keeping everything
/// already registered. iOS resolves a notification's category when the user expands it, not when it is
/// delivered, so a registered category has to outlive delivery: nothing but the oldest categories this
/// SDK registered itself is ever removed.
@interface PWActionButtonsRegistrar : NSObject

/// Registers into the current notification center, remembering recency in the standard user defaults.
- (instancetype)init;

/// Both collaborators are process-global singletons otherwise; this is the seam the tests drive.
- (instancetype)initWithNotificationCenter:(UNUserNotificationCenter *)center
                                  defaults:(NSUserDefaults *)defaults NS_DESIGNATED_INITIALIZER;

/// Identifier of the category these buttons make up. The same buttons always get the same identifier,
/// so a repeated campaign reuses its category instead of growing the set.
+ (NSString *)categoryIdentifierForButtons:(NSArray<PWActionButton *> *)buttons;

/// The category these buttons make up, under the identifier above.
+ (UNNotificationCategory *)categoryForButtons:(NSArray<PWActionButton *> *)buttons;

/// Registers that category. Completion runs exactly once: after iOS confirms the new set is in effect,
/// or right away when there is nothing to register. Serialized against every other registrar in the
/// process, so two pushes arriving together cannot drop each other's category.
- (void)registerCategoryForButtons:(NSArray<PWActionButton *> *)buttons
                        completion:(nullable void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END

#endif
