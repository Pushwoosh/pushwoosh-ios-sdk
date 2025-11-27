# ``Pushwoosh/LiveActivities``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to Live Activities functionality.

## Overview

Live Activities display real-time information on the Lock Screen and Dynamic Island. Use Pushwoosh to update Live Activities via push notifications.

Key capabilities:
- Start Live Activities via push (Push to Start)
- Update Live Activity content remotely
- End Live Activities from server

## Requirements

- iOS 16.1+ for Live Activities
- iOS 17.2+ for Push to Start
- ActivityKit framework
- Push Notifications entitlement

## Example

Set up Push to Start Live Activities:

```swift
@available(iOS 17.2, *)
func setupPushToStart() {
    Task {
        for await data in Activity<DeliveryAttributes>.pushToStartTokenUpdates {
            let token = data.map { String(format: "%02x", $0) }.joined()
            try? await Pushwoosh.LiveActivities.sendPushToStartLiveActivity(token: token)
        }
    }
}
```

Start a Live Activity and register with Pushwoosh:

```swift
func startDeliveryTracking(order: Order) async throws {
    let attributes = DeliveryAttributes(orderId: order.id, restaurantName: order.restaurant)
    let state = DeliveryContentState(status: .preparing, eta: order.estimatedDelivery)

    let activity = try Activity.request(
        attributes: attributes,
        content: .init(state: state, staleDate: nil),
        pushType: .token
    )

    for await tokenData in activity.pushTokenUpdates {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        try await Pushwoosh.LiveActivities.startLiveActivity(
            token: token,
            activityId: "order_\(order.id)"
        )
        break
    }
}
```

End Live Activity:

```swift
func completeDelivery(orderId: String) async {
    await activity.end(dismissalPolicy: .immediate)
    try? await Pushwoosh.LiveActivities.stopLiveActivity(activityId: "order_\(orderId)")
}
```

## See Also

- ``Pushwoosh/sendPushToStartLiveActivity(token:)``
- ``Pushwoosh/startLiveActivity(withToken:activityId:)``
- ``Pushwoosh/stopLiveActivity()``
