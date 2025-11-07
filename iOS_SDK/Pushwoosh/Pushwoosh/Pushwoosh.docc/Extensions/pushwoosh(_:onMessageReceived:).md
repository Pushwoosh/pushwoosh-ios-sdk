# ``PWMessagingDelegate/pushwoosh(_:onMessageReceived:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Called when the application receives a push notification.

## Discussion

This method is invoked when a push notification arrives, regardless of whether the app is in the foreground or background. Use this method to process notification content, update your UI, or trigger background work.

This method is called even when the app is in the foreground, allowing you to handle notifications without displaying the system alert.

## Parameters

- pushwoosh: The Pushwoosh instance that received the notification
- message: The notification message containing payload data, custom fields, and metadata

