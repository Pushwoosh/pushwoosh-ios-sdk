# ``Pushwoosh/registerForPushNotifications(with:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers the device for push notifications and sets initial tags.

## Discussion

This method combines device registration with tag assignment in a single call. It requests user permission for notifications, registers with APNs, and immediately sets the provided tags on the device.

This is equivalent to calling `registerForPushNotifications()` followed by `setTags:`, but more efficient as it combines both operations.

## Parameters

- tags: Dictionary of tag names and values to set during registration
