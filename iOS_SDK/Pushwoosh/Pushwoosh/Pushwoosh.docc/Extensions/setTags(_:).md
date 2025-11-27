# ``Pushwoosh/setTags(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sets user tags for device segmentation.

## Overview

Tags are key-value pairs that enable targeted push notifications based on user attributes and behavior. Use tags to:
- Segment users for targeted campaigns
- Personalize notification content
- Track user preferences and behavior
- A/B test notification strategies

## Supported Tag Types

| Type | Swift Type | Example |
|------|-----------|---------|
| String | `String` | `"city": "New York"` |
| Integer | `Int` | `"age": 25` |
| Boolean | `Bool` | `"isPremium": true` |
| List | `[String]` | `"interests": ["sports", "tech"]` |
| Date | `Date` | `"lastPurchase": Date()` |
| Incremental | `PWTagsBuilder` | See example below |

## Important

Tag names must be created in the Pushwoosh Control Panel before use. Sending unknown tag names will result in the tag being ignored.

## Example

Track user profile and preferences:

```swift
func updateUserProfile(_ profile: UserProfile) {
    let tags: [String: Any] = [
        "username": profile.username,
        "age": profile.age,
        "city": profile.city,
        "isPremium": profile.hasActiveSubscription,
        "interests": profile.interests,
        "lastActive": Date()
    ]

    Pushwoosh.configure.setTags(tags)
}
```

Track e-commerce behavior:

```swift
func trackPurchase(order: Order) {
    let tags: [String: Any] = [
        "lastPurchaseDate": Date(),
        "lastPurchaseAmount": order.total,
        "purchaseCount": PWTagsBuilder.incrementalTag(withInteger: 1),
        "totalSpent": PWTagsBuilder.incrementalTag(withInteger: Int(order.total)),
        "purchasedCategories": PWTagsBuilder.appendValues(toListTag: order.categoryNames)
    ]

    Pushwoosh.configure.setTags(tags)
}
```

Track app engagement:

```swift
func trackFeatureUsage(feature: String) {
    Pushwoosh.configure.setTags([
        "last_used_feature": feature,
        "feature_\(feature)_count": PWTagsBuilder.incrementalTag(withInteger: 1)
    ])
}
```

## See Also

- ``Pushwoosh/setTags(_:completion:)``
- ``Pushwoosh/getTags(_:onFailure:)``
- ``PWTagsBuilder``
