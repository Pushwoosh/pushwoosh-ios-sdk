# ``Pushwoosh/stopLiveActivity(with:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Stops a specific live activity by ID.

## Overview

> Deprecated: Use ``Pushwoosh/LiveActivities`` API instead.

Stops a live activity identified by its activity ID. Use this when managing multiple live activities and you need to stop a specific one.

## Example

Use the new LiveActivities API:

```swift
@available(iOS 16.1, *)
func cancelOrder(orderId: String) {
    Pushwoosh.LiveActivities.stopLiveActivity(activityId: orderId)

    Task {
        for activity in Activity<DeliveryAttributes>.activities {
            if activity.attributes.orderId == orderId {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
```

## See Also

- ``Pushwoosh/LiveActivities``
- ``Pushwoosh/stopLiveActivity(with:completion:)``
