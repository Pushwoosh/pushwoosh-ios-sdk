# ``Pushwoosh/sendBadges(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Synchronizes the application badge number with Pushwoosh servers.

## Overview

Sends the current badge value to Pushwoosh to enable server-side badge management. This allows:
- Auto-incrementing badges from server
- Badge-based segmentation
- Accurate badge analytics

## Automatic Handling

The SDK automatically intercepts changes to `UIApplication.applicationIconBadgeNumber` and syncs them. Manual calls are only needed when:
- Using custom badge management
- Syncing badge after background processing
- Resetting badge to specific value

## Example

Sync badge after marking notifications as read:

```swift
func markAllNotificationsAsRead() {
    let unreadCount = notificationStore.markAllAsRead()

    UIApplication.shared.applicationIconBadgeNumber = unreadCount
    Pushwoosh.configure.sendBadges(unreadCount)
}
```

Reset badge when user opens the app:

```swift
func applicationDidBecomeActive(_ application: UIApplication) {
    UIApplication.shared.applicationIconBadgeNumber = 0
    Pushwoosh.configure.sendBadges(0)
}
```

Update badge based on unread messages:

```swift
func updateBadgeForUnreadMessages() {
    let unreadCount = messageStore.unreadCount

    UIApplication.shared.applicationIconBadgeNumber = unreadCount
    Pushwoosh.configure.sendBadges(unreadCount)
}
```

## See Also

- ``Pushwoosh/registerForPushNotifications()``
