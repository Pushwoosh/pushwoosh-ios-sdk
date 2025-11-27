# ``Pushwoosh/registerForPushNotifications(completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers the device for push notifications with a completion handler.

## Overview

Same as ``registerForPushNotifications()`` but provides a completion callback with the registration result.

Use this variant when you need to:
- Confirm registration succeeded
- Get the push token immediately
- Handle registration errors
- Chain operations after registration

## Example

Register and wait for result:

```swift
func enablePushNotifications() {
    Pushwoosh.configure.registerForPushNotifications { token, error in
        if let error = error {
            self.showError("Push registration failed: \(error.localizedDescription)")
            return
        }

        if let token = token {
            self.syncTokenWithBackend(token)
        }

        self.updateUI(pushEnabled: true)
    }
}
```

Register with async/await:

```swift
func enablePushNotifications() async throws -> String? {
    try await withCheckedThrowingContinuation { continuation in
        Pushwoosh.configure.registerForPushNotifications { token, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: token)
            }
        }
    }
}
```

Show different UI based on result:

```swift
func requestPushPermission() {
    Pushwoosh.configure.registerForPushNotifications { token, error in
        DispatchQueue.main.async {
            if token != nil {
                self.showSuccessState()
            } else if let error = error as NSError?,
                      error.code == 3010 {
                self.showPermissionDeniedState()
            } else {
                self.showErrorState()
            }
        }
    }
}
```

## See Also

- ``Pushwoosh/registerForPushNotifications()``
- ``Pushwoosh/unregisterForPushNotifications(completion:)``
- ``Pushwoosh/getPushToken()``
