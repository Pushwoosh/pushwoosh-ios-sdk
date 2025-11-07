# ``Pushwoosh/registerForPushNotifications(completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers the device for push notifications with a completion handler.

## Discussion

This method initiates the push notification registration process and provides a callback when the operation completes. Use this when you need to know whether registration succeeded and want to receive the push token.

When called, the system displays a permission dialog to the user asking them to allow notifications. Once the user grants permission, the device receives a push token from APNs which is provided to the completion handler.

The registration process is asynchronous. Handle the push token in the completion block.

## Parameters

- completion: Block called when registration completes. Receives the push token string on success, or an error on failure.

## Example

```swift
Pushwoosh.sharedInstance().registerForPushNotifications { token, error in
    if let token = token {
        print("Successfully registered with token: \(token)")
    } else if let error = error {
        print("Registration failed: \(error.localizedDescription)")
    }
}
```
