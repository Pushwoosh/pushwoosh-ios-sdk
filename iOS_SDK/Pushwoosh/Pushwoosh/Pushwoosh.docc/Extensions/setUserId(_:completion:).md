# ``Pushwoosh/setUserId(_:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Associates a unique identifier with the current device with a completion handler.

## Overview

Same as ``setUserId(_:)`` but provides a completion callback to confirm the user ID was successfully synchronized with Pushwoosh servers.

Use this variant when you need to:
- Confirm user ID was set before proceeding
- Handle errors in user identification
- Chain operations that depend on user ID being set

## Example

Set user ID and wait for confirmation before loading personalized content:

```swift
func handleLogin(credentials: Credentials) async throws {
    let user = try await authService.login(credentials)

    try await withCheckedThrowingContinuation { continuation in
        Pushwoosh.configure.setUserId(user.id) { error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
    }

    await loadPersonalizedContent(for: user)
}
```

Handle user identification with error logging:

```swift
func identifyUser(_ userId: String) {
    Pushwoosh.configure.setUserId(userId) { error in
        if let error = error {
            Analytics.log("pushwoosh_user_id_failed", [
                "error": error.localizedDescription,
                "userId": userId
            ])
        } else {
            Analytics.log("pushwoosh_user_identified", [
                "userId": userId
            ])
        }
    }
}
```

## See Also

- ``Pushwoosh/setUserId(_:)``
- ``Pushwoosh/getUserId()``
- ``Pushwoosh/setEmail(_:completion:)``
