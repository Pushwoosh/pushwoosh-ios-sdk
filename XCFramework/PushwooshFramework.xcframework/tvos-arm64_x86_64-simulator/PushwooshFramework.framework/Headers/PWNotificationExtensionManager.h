//
//  PWNotificationExtensionManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2019
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Deprecated since 7.1.0. Subclass `PushwooshNotificationServiceExtension` instead — it is a
 ready-made `UNNotificationServiceExtension` base class that sends the message delivery event,
 sets the badge, downloads the media attachment and handles the `serviceExtensionTimeWillExpire`
 fallback for you.

 ```swift
 import PushwooshFramework

 class NotificationService: PushwooshNotificationServiceExtension {}
 ```

 This manager stays available as a low-level API for integrations that cannot subclass
 `PushwooshNotificationServiceExtension` — e.g. an extension that already extends another SDK's
 base class, or cross-platform wrappers (React Native / Flutter / Unity).
 */
__attribute__((deprecated("Since 7.1.0: subclass PushwooshNotificationServiceExtension instead.")))
@interface PWNotificationExtensionManager : NSObject

+ (instancetype)sharedManager __attribute__((deprecated("Since 7.1.0: subclass PushwooshNotificationServiceExtension instead.")));

/**
 Sends the message delivery event to Pushwoosh, sets the badge and downloads the media
 attachment. Call it from `UNNotificationServiceExtension`. Set `Pushwoosh_APPID` in the
 extension Info.plist.
 */
- (void)handleNotificationRequest:(UNNotificationRequest *)request
                   contentHandler:(void (^)(UNNotificationContent *))contentHandler
    __attribute__((deprecated("Since 7.1.0: subclass PushwooshNotificationServiceExtension instead.")));

/**
 Same as `handleNotificationRequest:contentHandler:`, with an explicit App Group name instead of
 reading `PW_APP_GROUPS_NAME` from the extension Info.plist.

 Behavior changed in 7.1.0: this method now also sends the message delivery event and downloads the
 media attachment (previously it only updated the badge). Both deprecated overloads now share the
 same processing path.
 */
- (void)handleNotificationRequest:(UNNotificationRequest *)request
                    withAppGroups:(NSString * _Nonnull)appGroupsName
                   contentHandler:(void (^ _Nonnull)(UNNotificationContent * _Nonnull))contentHandler
    __attribute__((deprecated("Since 7.1.0: subclass PushwooshNotificationServiceExtension instead.")));
@end

NS_ASSUME_NONNULL_END
