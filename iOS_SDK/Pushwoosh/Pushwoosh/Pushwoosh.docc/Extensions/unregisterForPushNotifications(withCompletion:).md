# ``Pushwoosh/unregisterForPushNotifications(withCompletion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Unregisters the device from push notifications with a completion handler.

## Overview

Similar to `unregisterForPushNotifications()` but provides a callback when the operation completes. Use this when you need to know whether unregistration succeeded.

## Example

Unregister during account logout:

```swift
func performLogout() {
    showLoadingIndicator()

    Pushwoosh.configure.unregisterForPushNotifications { error in
        DispatchQueue.main.async {
            self.hideLoadingIndicator()

            if let error = error {
                self.logger.warning("Failed to unregister push: \(error.localizedDescription)")
            }

            self.clearUserSession()
            self.navigateToLoginScreen()
        }
    }
}
```

Allow user to disable notifications in settings:

```swift
func toggleNotifications(_ enabled: Bool) {
    if enabled {
        Pushwoosh.configure.registerForPushNotifications()
    } else {
        Pushwoosh.configure.unregisterForPushNotifications { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showAlert(title: "Error", message: "Could not disable notifications.")
                    self.notificationSwitch.isOn = true
                } else {
                    self.showToast("Notifications disabled")
                }
            }
        }
    }
}
```

## See Also

- ``Pushwoosh/unregisterForPushNotifications()``
- ``Pushwoosh/registerForPushNotifications(withCompletion:)``
