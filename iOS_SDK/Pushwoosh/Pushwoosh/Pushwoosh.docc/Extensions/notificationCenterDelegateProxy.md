# ``Pushwoosh/notificationCenterDelegateProxy``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Proxy that manages UNUserNotificationCenterDelegate objects.

## Discussion

This property provides access to the notification center delegate proxy, which allows multiple objects to receive notification center delegate callbacks. Use this to add additional `UNUserNotificationCenterDelegate` implementations alongside Pushwoosh's default handling.

The proxy forwards delegate methods to all registered delegates, enabling multiple components to respond to notification events.

This is a read-only property.

