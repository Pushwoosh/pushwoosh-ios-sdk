# ``Pushwoosh/startLiveActivity(withToken:activityId:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sends live activity token to the server with a completion handler.

## Overview

> Deprecated: Use ``Pushwoosh/LiveActivities`` API instead.

Similar to `startLiveActivityWithToken:activityId:` but provides a callback when the operation completes.

## Example

Use the new LiveActivities API:

```swift
@available(iOS 16.1, *)
func startDeliveryTracking(orderId: String) async throws {
    let activity = try Activity.request(
        attributes: DeliveryAttributes(orderId: orderId),
        content: .init(state: DeliveryState(status: .preparing), staleDate: nil)
    )

    guard let token = activity.pushToken else { return }
    let tokenString = token.map { String(format: "%02x", $0) }.joined()

    Pushwoosh.LiveActivities.startLiveActivity(token: tokenString, activityId: orderId) { error in
        if let error = error {
            self.logger.error("Failed to register live activity: \(error)")
        } else {
            self.logger.info("Live activity registered for order: \(orderId)")
        }
    }
}
```

## See Also

- ``Pushwoosh/LiveActivities``
