# ``Pushwoosh/setEmails(_:)-32h1u``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers a list of email addresses with a completion handler.

## Overview

Same as ``Pushwoosh/setEmails(_:)-8qzt8`` but provides a completion callback to confirm the emails were successfully synchronized.

Use this variant when you need to:
- Confirm emails were registered before proceeding
- Show user feedback about registration status
- Handle validation errors

## Example

Register emails with confirmation:

```swift
func saveUserEmails(_ emails: [String], completion: @escaping (Bool) -> Void) {
    Pushwoosh.configure.setEmails(emails) { error in
        if let error = error {
            Analytics.log("emails_registration_failed", error: error)
            completion(false)
        } else {
            self.userDefaults.set(emails, forKey: "registeredEmails")
            completion(true)
        }
    }
}
```

Import emails from account with feedback:

```swift
func importAccountEmails() {
    let emails = accountService.verifiedEmails

    Pushwoosh.configure.setEmails(emails) { error in
        DispatchQueue.main.async {
            if error == nil {
                self.showSuccess("Emails synced successfully")
            } else {
                self.showError("Failed to sync emails")
            }
        }
    }
}
```

## See Also

- ``Pushwoosh/setEmails(_:)-8qzt8``
- ``Pushwoosh/setEmail(_:)-2x3e8``
