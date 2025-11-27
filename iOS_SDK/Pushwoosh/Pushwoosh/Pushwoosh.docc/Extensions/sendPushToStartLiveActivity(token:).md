# ``Pushwoosh/sendPushToStartLiveActivity(token:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sends push-to-start live activity token to the server.

## Overview

> Deprecated: Use ``Pushwoosh/LiveActivities`` API instead:
> ```swift
> Pushwoosh.LiveActivities.sendPushToStartLiveActivity(token: token)
> ```

Registers a Push to Start token with Pushwoosh to enable starting Live Activities via push notifications (iOS 17.2+).

## Example

Set up Push to Start:

```swift
@available(iOS 17.2, *)
func setupPushToStart() {
    Task {
        for await data in Activity<OrderAttributes>.pushToStartTokenUpdates {
            let token = data.map { String(format: "%02x", $0) }.joined()
            try? await Pushwoosh.LiveActivities.sendPushToStartLiveActivity(token: token)
        }
    }
}
```

## See Also

- ``Pushwoosh/LiveActivities``
- ``Pushwoosh/startLiveActivity(withToken:activityId:)``
