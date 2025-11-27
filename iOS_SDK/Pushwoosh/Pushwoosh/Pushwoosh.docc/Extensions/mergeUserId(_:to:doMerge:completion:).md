# ``Pushwoosh/mergeUserId(_:to:doMerge:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Merges or moves all events from one user ID to another.

## Overview

Transfers user data and events between user identifiers. Use this when:
- User links multiple accounts
- Migrating from anonymous to authenticated user
- Consolidating duplicate accounts
- User changes their identifier

## Merge vs Delete

- `doMerge: true` - All events from oldUserId are **moved** to newUserId
- `doMerge: false` - All events for oldUserId are **deleted**

## Example

Merge anonymous user data after login:

```swift
func handleLogin(authenticatedUserId: String) {
    let anonymousId = Pushwoosh.configure.getUserId()

    Pushwoosh.configure.mergeUserId(
        anonymousId,
        to: authenticatedUserId,
        doMerge: true
    ) { error in
        if let error = error {
            Analytics.log("user_merge_failed", error: error)
        } else {
            Pushwoosh.configure.setUserId(authenticatedUserId)
        }
    }
}
```

Handle account linking:

```swift
func linkAccounts(primaryId: String, secondaryId: String) {
    Pushwoosh.configure.mergeUserId(
        secondaryId,
        to: primaryId,
        doMerge: true
    ) { error in
        if error == nil {
            self.showSuccess("Accounts linked successfully")
        }
    }
}
```

Delete data for old user ID:

```swift
func handleAccountDeletion(userId: String) {
    Pushwoosh.configure.mergeUserId(
        userId,
        to: "",
        doMerge: false
    ) { error in
        if error == nil {
            self.clearLocalUserData()
        }
    }
}
```

## See Also

- ``Pushwoosh/setUserId(_:)``
- ``Pushwoosh/setUserId(_:completion:)``
- ``Pushwoosh/getUserId()``
