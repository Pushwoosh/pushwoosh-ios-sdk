# ``Pushwoosh/getUserId()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Returns the current user identifier.

## Overview

The user ID is used to identify users across multiple devices and sessions. This enables:
- Cross-device push notification targeting
- User-level analytics and segmentation
- Merging user data when users log in on new devices

## Default Behavior

If no custom user ID has been set via ``setUserId(_:)``, this method returns the Hardware ID (HWID) as the default identifier.

## Example

Sync Pushwoosh user ID with your analytics platform:

```swift
func setupAnalytics() {
    let userId = Pushwoosh.configure.getUserId()

    Analytics.shared.identify(userId)
    Crashlytics.setUserID(userId)
}
```

Include user ID in support tickets:

```swift
func createSupportTicket(issue: String) -> SupportTicket {
    return SupportTicket(
        userId: Pushwoosh.configure.getUserId(),
        hwid: Pushwoosh.configure.getHWID(),
        issue: issue,
        appVersion: Bundle.main.appVersion
    )
}
```

## See Also

- ``Pushwoosh/setUserId(_:)``
- ``Pushwoosh/setUserId(_:completion:)``
- ``Pushwoosh/getHWID()``
