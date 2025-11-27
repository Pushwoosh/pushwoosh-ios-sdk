# ``Pushwoosh/stopLiveActivity(with:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Stops a specific live activity by ID with a completion handler.

## Overview

> Deprecated: Use ``Pushwoosh/LiveActivities`` API instead.

Similar to `stopLiveActivityWith:` but provides a callback when the operation completes.

## Example

Use the new LiveActivities API:

```swift
@available(iOS 16.1, *)
func cancelDelivery(orderId: String) {
    Pushwoosh.LiveActivities.stopLiveActivity(activityId: orderId) { error in
        if let error = error {
            self.logger.error("Failed to stop activity \(orderId): \(error)")
            return
        }

        self.logger.info("Stopped live activity for order: \(orderId)")
        self.updateOrderStatus(orderId, status: .cancelled)
    }

    Task {
        for activity in Activity<DeliveryAttributes>.activities {
            if activity.attributes.orderId == orderId {
                await activity.end(
                    .init(state: DeliveryState(status: .cancelled), staleDate: nil),
                    dismissalPolicy: .after(.now + 3600)
                )
            }
        }
    }
}
```

## See Also

- ``Pushwoosh/LiveActivities``
- ``Pushwoosh/stopLiveActivity(with:)``
