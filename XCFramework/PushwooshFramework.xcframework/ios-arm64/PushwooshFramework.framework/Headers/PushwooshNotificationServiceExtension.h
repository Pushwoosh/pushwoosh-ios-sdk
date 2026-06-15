//
//  PushwooshNotificationServiceExtension.h
//  Pushwoosh SDK
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

#if TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

/**
 Drop-in base class for a Notification Service Extension. Subclass it (or set it directly as
 the extension's `NSExtensionPrincipalClass`) and Pushwoosh handles everything required for a
 push: sending the message delivery event, badge counting, downloading the media attachment,
 and the mandatory `serviceExtensionTimeWillExpire` fallback.

 Minimal integration — no code required beyond the subclass:

 ```swift
 import PushwooshFramework

 class NotificationService: PushwooshNotificationServiceExtension {}
 ```

 Or point the extension's Info.plist `NSExtensionPrincipalClass` at
 `PushwooshNotificationServiceExtension` directly and write no Swift/Obj-C at all.

 Requirements:
 - `Pushwoosh_APPID` in the main app Info.plist. You do not need to duplicate it in the extension
   Info.plist — when missing there, Pushwoosh inherits it (and other `Pushwoosh_*` keys) from the
   host app. Set it explicitly in the extension Info.plist only to override the host.
 - `mutable-content: 1` in the push payload (so the extension is invoked).
 - App Group shared between the app and the extension for badge / reverse-proxy sync
   (set `PW_APP_GROUPS_NAME` in Info.plist or override `pushwooshAppGroupsName`).
   Note: if the host app uses a reverse proxy (`Pushwoosh_ALLOW_REVERSE_PROXY`), the extension
   needs this App Group to read the proxy URL the app stored there — otherwise the delivery event
   is held back (it will not bypass the proxy). Add the App Group capability to the extension target.

 Customization, from least to most control:
 - Override `pushwooshAppGroupsName` to set the App Group programmatically.
 - Override `pushwooshPrepareForRequest:completion:` to run async preparation before processing
   (e.g. Push Stories media prefetch) without touching the standard `didReceive`.
 - Override the standard `didReceiveNotificationRequest:withContentHandler:` to customize the
   content before it is shown: call `super` with your own content handler, mutate the content
   inside it, then forward to the original handler. Pushwoosh still runs the delivery event,
   badge, attachment and timeout fallback.

   ```swift
   override func didReceive(_ request: UNNotificationRequest,
                            withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
       super.didReceive(request) { content in
           let mutable = (content.mutableCopy() as? UNMutableNotificationContent) ?? content
           // customize `mutable` here
           contentHandler(mutable)
       }
   }
   ```

   For full control, skip `super` and drive everything yourself (in that case send the delivery
   event via `PWNotificationExtensionManager`).
 */
API_AVAILABLE(ios(10.0))
@interface PushwooshNotificationServiceExtension : UNNotificationServiceExtension

/**
 Called before Pushwoosh processes the push. Override to run asynchronous preparation — for
 example, prefetching Push Stories media into a shared App Group container — without overriding
 the standard `didReceive`. Processing (delivery event, badge, attachment) continues only after
 `completion` fires, so always call it exactly once, on the main thread.

 Default implementation calls `completion` immediately.

 @param request The original notification request.
 @param completion Block to invoke when preparation is finished. Call it exactly once, on the main
        thread (the thread the system delivers `didReceive` on).
 */
- (void)pushwooshPrepareForRequest:(UNNotificationRequest *)request
                        completion:(void (^)(void))completion;

/**
 The App Group used to sync badge count and reverse-proxy settings with the host app.

 Default returns `nil`, in which case Pushwoosh reads `PW_APP_GROUPS_NAME` from the extension
 Info.plist. Override to provide the App Group programmatically.
 */
- (nullable NSString *)pushwooshAppGroupsName;

@end

NS_ASSUME_NONNULL_END

#endif
