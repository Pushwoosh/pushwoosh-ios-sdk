# ``Pushwoosh/setTags(_:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sets user tags with a completion handler.

## Overview

Same as ``setTags(_:)`` but provides a completion callback to confirm the tags were successfully synchronized with Pushwoosh servers.

Use this variant when you need to:
- Confirm tags were set before proceeding
- Handle tag synchronization errors
- Show user feedback about preference updates

## Example

Update user preferences with confirmation:

```swift
func saveNotificationPreferences(_ preferences: NotificationPreferences) {
    let tags: [String: Any] = [
        "notify_orders": preferences.orderUpdates,
        "notify_promotions": preferences.promotionalOffers,
        "notify_news": preferences.newsAndUpdates
    ]

    Pushwoosh.configure.setTags(tags) { error in
        DispatchQueue.main.async {
            if let error = error {
                self.showAlert("Failed to save preferences: \(error.localizedDescription)")
            } else {
                self.showToast("Preferences saved")
            }
        }
    }
}
```

Track subscription upgrade with analytics:

```swift
func handleSubscriptionUpgrade(to tier: SubscriptionTier) {
    let tags: [String: Any] = [
        "subscription_tier": tier.rawValue,
        "subscription_updated": Date(),
        "isPremium": tier != .free
    ]

    Pushwoosh.configure.setTags(tags) { error in
        if error == nil {
            Analytics.log("subscription_synced_to_pushwoosh", [
                "tier": tier.rawValue
            ])
        }
    }
}
```

## See Also

- ``Pushwoosh/setTags(_:)``
- ``Pushwoosh/getTags(_:onFailure:)``
