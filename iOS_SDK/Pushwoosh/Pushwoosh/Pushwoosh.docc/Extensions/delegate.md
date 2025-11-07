# ``Pushwoosh/delegate``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Delegate that receives push notification events.

## Discussion

Set this property to an object conforming to `PWMessagingDelegate` to receive callbacks when push notifications are received or opened. The delegate receives information about events such as registering with APNs, receiving push notifications, and handling user interactions with notifications.

Pushwoosh Runtime sets this to ApplicationDelegate by default, but you can override it with your own delegate object.

