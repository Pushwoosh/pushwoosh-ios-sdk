# ``Pushwoosh/setTags(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sets user tags for device segmentation.

## Discussion

Tags are key-value pairs that enable targeted push notifications based on user attributes and behavior. Use tags to segment your audience and send personalized messages to specific user groups.

Supported tag types:
- **String**: Text values (e.g., username, city)
- **Integer**: Numeric values (e.g., age, score)
- **Boolean**: True/false values (e.g., isPremium, hasSubscription)
- **List**: Arrays of strings (e.g., interests, categories)
- **Incremental**: Integer counters that can be incremented/decremented
- **Date**: NSDate objects for time-based segmentation

Tag names must be created in the Pushwoosh Control Panel before use. Tags are set asynchronously and do not block the calling thread.

## Parameters

- tags: Dictionary of tag names and values to set for the current device
