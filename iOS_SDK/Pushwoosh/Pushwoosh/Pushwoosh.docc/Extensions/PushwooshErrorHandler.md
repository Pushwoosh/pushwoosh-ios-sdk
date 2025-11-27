# ``PushwooshErrorHandler``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Completion handler called when an operation fails.

## Overview

This closure is called when a Pushwoosh operation fails, providing an error object describing what went wrong.

The handler receives an optional `NSError` parameter. If the error is `nil`, the operation succeeded (though typically success handlers use different callback types).

## Example

Handle tag setting errors with retry logic:

```swift
func setUserPreferences(_ preferences: [String: Any], retryCount: Int = 0) {
    let errorHandler: PushwooshErrorHandler = { error in
        if let error = error {
            self.logger.error("Failed to set tags: \(error.localizedDescription)")

            if retryCount < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.setUserPreferences(preferences, retryCount: retryCount + 1)
                }
            } else {
                self.showAlert(title: "Sync Error", message: "Could not save preferences. Please try again later.")
            }
        }
    }

    Pushwoosh.configure.setTags(preferences, onFailure: errorHandler)
}
```

## See Also

- ``PushwooshRegistrationHandler``
- ``PushwooshGetTagsHandler``

