# ``Pushwoosh/getPushToken()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Retrieves the current device push token.

## Discussion

Returns the APNs device token string that was received during push notification registration. The token is used to send push notifications to this specific device.

The push token becomes available after successful registration with `registerForPushNotifications()`.

## Returns

The device push token as a hexadecimal string, or `nil` if the device hasn't registered for push notifications yet
