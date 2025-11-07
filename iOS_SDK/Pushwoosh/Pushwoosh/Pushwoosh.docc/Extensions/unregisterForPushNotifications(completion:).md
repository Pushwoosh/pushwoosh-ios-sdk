# ``Pushwoosh/unregisterForPushNotifications(completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Unregisters the device from push notifications with a completion handler.

## Discussion

Similar to `unregisterForPushNotifications()` but provides a callback when the operation completes. Use this when you need to know whether unregistration succeeded.

This method removes the device from receiving push notifications and notifies Pushwoosh servers to stop sending notifications to this device token. The completion handler is called after the operation finishes.

## Parameters

- completion: Block called when unregistration completes. Receives nil on success or an NSError on failure.

## Example

```swift
Pushwoosh.sharedInstance().unregisterForPushNotifications { error in
    if let error = error {
        print("Unregistration failed: \(error.localizedDescription)")
    } else {
        print("Successfully unregistered from push notifications")
    }
}
```

## Note

Unregistration is permanent until `registerForPushNotifications()` is called again.
