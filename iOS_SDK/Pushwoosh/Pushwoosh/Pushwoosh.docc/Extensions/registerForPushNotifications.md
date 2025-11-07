# ``Pushwoosh/registerForPushNotifications()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers the device for push notifications.

## Discussion

This method initiates the push notification registration process by requesting user permission to display notifications and registering the device with Apple Push Notification service (APNs).

When called, the system will display a permission dialog to the user asking them to allow notifications. Once the user grants permission, the device will receive a push token from APNs which will be automatically sent to Pushwoosh servers for future push notification delivery.

The registration process is asynchronous. The device token will be handled automatically by the SDK.

This method should be called after configuring the Pushwoosh App Code in Info.plist with key `Pushwoosh_APPID`.

The permission dialog will only be shown once. If the user denies permission, subsequent calls will not show the dialog again. Users must manually enable notifications in Settings.
