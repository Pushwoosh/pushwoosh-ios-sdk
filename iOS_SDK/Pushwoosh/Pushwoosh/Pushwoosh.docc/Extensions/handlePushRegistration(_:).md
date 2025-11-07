# ``Pushwoosh/handlePushRegistration(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Manually handles the device push token registration.

## Discussion

Call this method from your AppDelegate's `application:didRegisterForRemoteNotificationsWithDeviceToken:` to forward the device token to Pushwoosh. The SDK normally handles this automatically, but you can call this method directly if you're managing the registration flow manually.

The device token is sent to Pushwoosh servers for push notification delivery to this specific device.

## Parameters

- devToken: The device token received from APNs
