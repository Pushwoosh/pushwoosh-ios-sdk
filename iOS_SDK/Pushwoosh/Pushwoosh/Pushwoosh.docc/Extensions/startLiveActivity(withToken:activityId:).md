# ``Pushwoosh/startLiveActivity(withToken:activityId:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sends live activity token to the server.

## Overview

> Deprecated: Use ``Pushwoosh/LiveActivities`` API instead:
> ```swift
> Pushwoosh.LiveActivities.startLiveActivity(token: token, activityId: activityId)
> ```

Registers a Live Activity token with Pushwoosh to enable remote updates.

## Example

Register Live Activity after creation:

```swift
func startOrderTracking(orderId: String) async throws {
    let activity = try Activity.request(
        attributes: OrderAttributes(orderId: orderId),
        content: .init(state: initialState, staleDate: nil),
        pushType: .token
    )

    for await tokenData in activity.pushTokenUpdates {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        try await Pushwoosh.LiveActivities.startLiveActivity(
            token: token,
            activityId: "order_\(orderId)"
        )
        break
    }
}
```

## See Also

- ``Pushwoosh/LiveActivities``
- ``Pushwoosh/stopLiveActivity()``
