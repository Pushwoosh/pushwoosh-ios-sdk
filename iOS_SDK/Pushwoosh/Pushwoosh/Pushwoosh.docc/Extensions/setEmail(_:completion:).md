# ``Pushwoosh/setEmail(_:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Associates an email address with the current device with a completion handler.

## Overview

Same as ``setEmail(_:)`` but provides a completion callback to confirm the email was successfully synchronized with Pushwoosh servers.

Use this variant when you need to:
- Confirm email was registered before proceeding
- Show feedback to user about registration status
- Handle validation errors

## Example

Register email with user feedback:

```swift
func submitEmail(_ email: String) {
    showLoadingIndicator()

    Pushwoosh.configure.setEmail(email) { error in
        DispatchQueue.main.async {
            self.hideLoadingIndicator()

            if let error = error {
                self.showError("Failed to register email: \(error.localizedDescription)")
            } else {
                self.showSuccess("Email registered successfully")
                self.proceedToNextStep()
            }
        }
    }
}
```

Validate email before enabling features:

```swift
func enableEmailNotifications(email: String, completion: @escaping (Bool) -> Void) {
    Pushwoosh.configure.setEmail(email) { error in
        if error == nil {
            self.userDefaults.set(true, forKey: "emailNotificationsEnabled")
        }
        completion(error == nil)
    }
}
```

## See Also

- ``Pushwoosh/setEmail(_:)``
- ``Pushwoosh/setEmails(_:)``
- ``Pushwoosh/setUserId(_:completion:)``
