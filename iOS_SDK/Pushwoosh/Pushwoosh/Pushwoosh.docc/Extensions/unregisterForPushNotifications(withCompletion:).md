# ``Pushwoosh/unregisterForPushNotifications(withCompletion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Unregisters the device from push notifications with a completion handler.

## Discussion

Similar to `unregisterForPushNotifications()` but provides a callback when the operation completes. Use this when you need to know whether unregistration succeeded.

## Parameters

- completion: Block called when unregistration completes, providing an error if the operation failed
