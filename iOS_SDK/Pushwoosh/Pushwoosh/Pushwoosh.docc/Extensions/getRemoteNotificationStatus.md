# ``Pushwoosh/getRemoteNotificationStatus()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Returns a dictionary with enabled remote notification types.

## Overview

Retrieves the current push notification permission status. Use this to:
- Check if user has enabled notifications
- Determine which notification types are allowed
- Show appropriate UI based on permission state
- Debug notification issues

## Response Format

```
{
   enabled = 1;      // Device can receive pushes
   pushAlert = 1;    // Alerts enabled
   pushBadge = 1;    // Badges enabled
   pushSound = 1;    // Sounds enabled
   type = 7;         // UIUserNotificationType bitmask
}
```

## Example

Check notification status and prompt user:

```swift
func checkNotificationPermissions() {
    guard let status = Pushwoosh.configure.getRemoteNotificationStatus() else {
        return
    }

    let enabled = status["enabled"] as? Bool ?? false
    let alertsEnabled = status["pushAlert"] as? Bool ?? false

    if !enabled {
        showEnableNotificationsPrompt()
    } else if !alertsEnabled {
        showNotificationsDisabledInSettingsAlert()
    }
}
```

Display notification settings in app:

```swift
func loadNotificationSettings() -> NotificationSettings {
    guard let status = Pushwoosh.configure.getRemoteNotificationStatus() else {
        return NotificationSettings.default
    }

    return NotificationSettings(
        enabled: status["enabled"] as? Bool ?? false,
        alerts: status["pushAlert"] as? Bool ?? false,
        badges: status["pushBadge"] as? Bool ?? false,
        sounds: status["pushSound"] as? Bool ?? false
    )
}
```

Log notification status for debugging:

```swift
func debugNotificationStatus() {
    if let status = Pushwoosh.configure.getRemoteNotificationStatus() {
        print("Notification status: \(status)")
    }
}
```

## See Also

- ``Pushwoosh/registerForPushNotifications()``
