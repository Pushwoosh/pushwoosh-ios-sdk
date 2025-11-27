# ``PushwooshRegistrationHandler``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Completion handler called when push notification registration completes.

## Overview

This closure is called when the device registration process finishes, either successfully or with an error.

The handler receives two parameters:
- **token**: The push token string if registration succeeded, or `nil` if it failed
- **error**: An error object if registration failed, or `nil` if it succeeded

## Example

Handle registration result with UI updates and backend sync:

```swift
func registerForNotifications() {
    let registrationHandler: PushwooshRegistrationHandler = { token, error in
        if let error = error {
            self.logger.error("Push registration failed: \(error.localizedDescription)")
            self.updateNotificationStatus(.failed)
            return
        }

        guard let token = token else { return }

        self.logger.info("Push token received: \(token.prefix(20))...")
        self.updateNotificationStatus(.registered)

        self.syncPushTokenWithBackend(token)
    }

    Pushwoosh.configure.registerForPushNotifications(withCompletion: registrationHandler)
}

func syncPushTokenWithBackend(_ token: String) {
    let hwid = Pushwoosh.configure.getHWID()
    apiClient.post("/devices/register", body: [
        "push_token": token,
        "hwid": hwid,
        "platform": "ios"
    ])
}
```

## See Also

- ``Pushwoosh/registerForPushNotifications(withCompletion:)``
- ``PushwooshErrorHandler``

