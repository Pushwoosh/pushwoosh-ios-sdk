# ``Pushwoosh/setUserId(_:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Associates a unique identifier with the current device with a completion handler.

## Discussion

Set a user identifier to track the same user across multiple devices. This can be any unique string such as a Facebook ID, username, email, or your own internal user ID.

The user ID is synchronized with Pushwoosh servers asynchronously.

## Parameters

- userId: The unique user identifier
- completion: Completion handler called when the operation finishes. Receives nil on success or an NSError on failure.
