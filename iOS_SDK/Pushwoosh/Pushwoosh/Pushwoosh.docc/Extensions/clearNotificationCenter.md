# ``Pushwoosh/clearNotificationCenter()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Clears all notifications from the notification center.

## Overview

Removes all delivered notifications for your app from iOS Notification Center. Use this to:
- Clean up when user opens the app
- Clear notifications after user reads content
- Remove outdated notifications
- Provide a fresh notification experience

## Example

Clear notifications when app becomes active:

```swift
func applicationDidBecomeActive(_ application: UIApplication) {
    Pushwoosh.configure.clearNotificationCenter()

    UIApplication.shared.applicationIconBadgeNumber = 0
    Pushwoosh.configure.sendBadges(0)
}
```

Clear notifications when user views notification inbox:

```swift
func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    Pushwoosh.configure.clearNotificationCenter()
    loadInboxMessages()
}
```

Clear after handling notification:

```swift
func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
    handleDeepLink(from: message)

    Pushwoosh.configure.clearNotificationCenter()
}
```

## See Also

- ``Pushwoosh/sendBadges(_:)``
