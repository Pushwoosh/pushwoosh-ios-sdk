# ``Pushwoosh/registerForPushNotifications(with:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers the device for push notifications and sets initial tags.

## Overview

This method combines device registration with tag assignment in a single call. It requests user permission for notifications, registers with APNs, and immediately sets the provided tags on the device.

This is equivalent to calling `registerForPushNotifications()` followed by `setTags:`, but more efficient as it combines both operations.

## Example

Register with user context tags:

```swift
func completeOnboarding(user: OnboardingResult) {
    let initialTags: [String: Any] = [
        "onboarding_completed": true,
        "interests": user.selectedInterests,
        "language": Locale.current.languageCode ?? "en",
        "timezone": TimeZone.current.identifier
    ]

    Pushwoosh.configure.registerForPushNotifications(with: initialTags)
}
```

Register with app version and install source:

```swift
func setupPushNotifications() {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let installSource = InstallTracker.getInstallSource()

    Pushwoosh.configure.registerForPushNotifications(with: [
        "app_version": appVersion ?? "unknown",
        "install_source": installSource,
        "first_launch": true
    ])
}
```

## See Also

- ``Pushwoosh/registerForPushNotifications(with:completion:)``
- ``Pushwoosh/registerForPushNotifications()``
