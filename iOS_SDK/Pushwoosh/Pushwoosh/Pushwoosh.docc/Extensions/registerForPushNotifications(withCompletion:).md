# ``Pushwoosh/registerForPushNotifications(withCompletion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers the device for push notifications with a completion handler.

## Overview

This method initiates the push notification registration process and provides a callback when the operation completes. Use this when you need to know whether registration succeeded and want to receive the push token.

When called, the system displays a permission dialog. Once the user grants permission, the device receives a push token from APNs.

## Example

Register with completion handling and UI updates:

```swift
func requestNotificationPermission() {
    showLoadingIndicator()

    Pushwoosh.configure.registerForPushNotifications { token, error in
        DispatchQueue.main.async {
            self.hideLoadingIndicator()

            if let error = error {
                self.handleRegistrationError(error)
                return
            }

            self.notificationStatusLabel.text = "Notifications enabled"
            self.notificationSwitch.isOn = true

            if let token = token {
                self.syncTokenWithBackend(token)
            }
        }
    }
}

func handleRegistrationError(_ error: Error) {
    if (error as NSError).code == 3010 {
        showAlert(
            title: "Notifications Disabled",
            message: "Please enable notifications in Settings to receive updates."
        )
    } else {
        logger.error("Push registration error: \(error)")
    }
}
```

## See Also

- ``Pushwoosh/registerForPushNotifications()``
- ``PushwooshRegistrationHandler``
