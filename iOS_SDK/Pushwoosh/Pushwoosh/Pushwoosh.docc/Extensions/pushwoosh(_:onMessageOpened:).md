# ``PWMessagingDelegate/pushwoosh(_:onMessageOpened:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Called when the user taps on a push notification.

## Discussion

This method is invoked when a user interacts with a push notification by tapping on it. Use this method to navigate to relevant content, open deep links, or perform actions based on the notification.

This method is only called when the user explicitly taps the notification, not when it's received.

## Parameters

- pushwoosh: The Pushwoosh instance that received the notification
- message: The notification message that was opened, containing payload data and custom fields

