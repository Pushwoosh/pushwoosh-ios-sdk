# ``Pushwoosh/unregisterForPushNotifications()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Unregisters the device from push notifications.

## Discussion

Removes the device from receiving push notifications. This method disables push notifications for the current device and notifies Pushwoosh servers to stop sending notifications to this device token.

Unregistration is permanent until `registerForPushNotifications()` is called again.
