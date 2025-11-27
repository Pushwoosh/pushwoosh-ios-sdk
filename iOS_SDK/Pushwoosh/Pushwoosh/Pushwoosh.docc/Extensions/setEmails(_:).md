# ``Pushwoosh/setEmails(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers a list of email addresses associated with the current user.

## Overview

Associates multiple email addresses with the device. Use this when:
- User has multiple email addresses (personal + work)
- Migrating from another system with multiple emails
- Supporting family/shared accounts

All emails receive campaigns targeted at this user.

## Example

Register multiple user emails:

```swift
func syncUserEmails(_ user: User) {
    var emails = [user.primaryEmail]

    if let workEmail = user.workEmail {
        emails.append(workEmail)
    }

    if let secondaryEmail = user.secondaryEmail {
        emails.append(secondaryEmail)
    }

    Pushwoosh.configure.setEmails(emails)
}
```

Import emails from account settings:

```swift
func importEmailsFromSettings() {
    let emails = accountSettings.verifiedEmails

    guard !emails.isEmpty else { return }

    Pushwoosh.configure.setEmails(emails)
}
```

## See Also

- ``Pushwoosh/setEmails(_:completion:)``
- ``Pushwoosh/setEmail(_:)``
- ``Pushwoosh/setUserId(_:)``
