# ``PushwooshGetTagsHandler``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Completion handler called when tags are successfully retrieved from the server.

## Overview

This closure is called when the `getTags:onFailure:` method successfully retrieves device tags from Pushwoosh servers.

The handler receives a dictionary where keys are tag names and values are the corresponding tag values. The dictionary can contain various types including strings, numbers, booleans, dates, and arrays.

## Example

Sync user preferences from Pushwoosh tags:

```swift
func loadUserPreferences() {
    let successHandler: PushwooshGetTagsHandler = { tags in
        guard let tags = tags else { return }

        if let subscriptionTier = tags["subscription_tier"] as? String {
            self.userSettings.subscriptionTier = subscriptionTier
        }

        if let favoriteCategories = tags["favorite_categories"] as? [String] {
            self.userSettings.favoriteCategories = favoriteCategories
        }

        if let notificationsEnabled = tags["notifications_enabled"] as? Bool {
            self.userSettings.notificationsEnabled = notificationsEnabled
        }

        self.refreshUI()
    }

    let errorHandler: PushwooshErrorHandler = { error in
        self.logger.error("Failed to load preferences: \(error?.localizedDescription ?? "Unknown error")")
    }

    Pushwoosh.configure.getTags(successHandler, onFailure: errorHandler)
}
```

## See Also

- ``PushwooshErrorHandler``
- ``Pushwoosh/getTags(_:onFailure:)``

