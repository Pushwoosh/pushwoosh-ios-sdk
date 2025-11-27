# ``Pushwoosh/stopLiveActivity(withCompletion:)``

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
func endAllLiveActivities() {
    Pushwoosh.LiveActivities.stopLiveActivity { error in
        if let error = error {
            self.logger.error("Failed to unregister live activities: \(error)")
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
- ``Pushwoosh/stopLiveActivity(completion:)``
