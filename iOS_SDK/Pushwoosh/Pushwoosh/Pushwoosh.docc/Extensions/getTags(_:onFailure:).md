# ``Pushwoosh/getTags(_:onFailure:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Retrieves the current device's tags from the Pushwoosh server.

## Overview

Fetches all tags currently set for this device. Use this to:
- Sync local state with server-side tags
- Display user preferences in settings
- Verify tags were set correctly
- Build conditional logic based on tag values

## Response Format

Tags are returned as a dictionary where:
- Keys are tag names (String)
- Values are tag values (can be String, Int, Bool, Array, or Date)

## Example

Load user preferences from tags:

```swift
func loadUserPreferences() {
    Pushwoosh.configure.getTags({ tags in
        guard let tags = tags else { return }

        self.userPreferences.isPremium = tags["isPremium"] as? Bool ?? false
        self.userPreferences.language = tags["language"] as? String ?? "en"
        self.userPreferences.interests = tags["interests"] as? [String] ?? []

        self.updateUI()
    }, onFailure: { error in
        Analytics.log("tags_load_failed", error: error)
    })
}
```

Check if user has specific tag before showing content:

```swift
func shouldShowPremiumContent(completion: @escaping (Bool) -> Void) {
    Pushwoosh.configure.getTags({ tags in
        let isPremium = tags?["isPremium"] as? Bool ?? false
        completion(isPremium)
    }, onFailure: { _ in
        completion(false)
    })
}
```

Debug current tag values:

```swift
func debugPrintTags() {
    Pushwoosh.configure.getTags({ tags in
        if let tags = tags {
            for (key, value) in tags {
                print("\(key): \(value)")
            }
        }
    }, onFailure: { error in
        print("Failed to get tags: \(error?.localizedDescription ?? "Unknown")")
    })
}
```

## See Also

- ``Pushwoosh/setTags(_:)``
- ``Pushwoosh/setTags(_:completion:)``
