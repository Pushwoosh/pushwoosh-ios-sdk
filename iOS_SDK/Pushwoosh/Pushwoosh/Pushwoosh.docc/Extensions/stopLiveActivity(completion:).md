# ``Pushwoosh/stopLiveActivity(completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Stops the current live activity with a completion handler.

## Overview

> Deprecated: Use ``Pushwoosh/LiveActivities`` API instead.

Similar to `stopLiveActivity()` but provides a callback when the operation completes.

## Example

Use the new LiveActivities API:

```swift
@available(iOS 16.1, *)
func completeDelivery(orderId: String) {
    Pushwoosh.LiveActivities.stopLiveActivity { error in
        if let error = error {
            self.logger.error("Failed to stop live activity: \(error)")
        } else {
            self.logger.info("Live activity stopped for order: \(orderId)")
        }
    }

    Task {
        for activity in Activity<DeliveryAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
```

## See Also

- ``Pushwoosh/LiveActivities``
