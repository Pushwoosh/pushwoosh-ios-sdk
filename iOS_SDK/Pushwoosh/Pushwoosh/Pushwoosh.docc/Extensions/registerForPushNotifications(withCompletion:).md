# ``Pushwoosh/registerForPushNotifications(withCompletion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers the device for push notifications with a completion handler.

## Discussion

This method initiates the push notification registration process and provides a callback when the operation completes. Use this when you need to know whether registration succeeded and want to receive the push token.

When called, the system displays a permission dialog. Once the user grants permission, the device receives a push token from APNs.

## Parameters

- completion: Block called when registration completes, providing the push token or an error
