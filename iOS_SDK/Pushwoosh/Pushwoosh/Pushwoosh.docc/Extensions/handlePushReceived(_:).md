# ``Pushwoosh/handlePushReceived(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Handles received push notifications.

## Discussion

Call this method to manually process a push notification payload. The SDK typically handles this automatically, but you can use this method if you need custom notification processing.

Returns `true` if the notification was handled by Pushwoosh, `false` otherwise.

## Parameters

- userInfo: The notification payload dictionary

## Returns

Boolean indicating whether the notification was processed by Pushwoosh
