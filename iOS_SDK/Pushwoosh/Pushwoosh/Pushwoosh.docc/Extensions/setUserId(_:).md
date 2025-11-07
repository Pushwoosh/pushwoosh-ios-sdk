# ``Pushwoosh/setUserId(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Associates a unique identifier with the current device.

## Discussion

Set a user identifier to track the same user across multiple devices. This can be any unique string such as a Facebook ID, username, email, or your own internal user ID. User identification enables cross-device data matching and provides better analytics.

The user ID is synchronized with Pushwoosh servers asynchronously.

## Parameters

- userId: The unique user identifier
