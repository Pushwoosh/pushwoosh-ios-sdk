# ``Pushwoosh/registerForPushNotifications(with:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers the device for push notifications with initial tags and a completion handler.

## Discussion

This method combines device registration and tag assignment, providing a callback when the operation completes. Use this when you need to know whether registration succeeded and want to set initial tags.

The tags are only set if registration succeeds. If registration fails, the tags will not be applied.

## Parameters

- tags: Dictionary of tag names and values to set during registration
- completion: Block called when registration completes, providing the push token or an error
