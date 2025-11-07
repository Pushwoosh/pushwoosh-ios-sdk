# ``Pushwoosh/sendBadges(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Synchronizes the application badge number with Pushwoosh servers.

## Discussion

Sends the current badge value to the server to enable auto-incrementing badge functionality. The SDK automatically calls this method when the application badge is modified, but you can call it manually if needed for custom badge management.

The SDK automatically intercepts `UIApplication.applicationIconBadgeNumber` changes, so manual calls are rarely needed.

## Parameters

- badge: The current application badge number
