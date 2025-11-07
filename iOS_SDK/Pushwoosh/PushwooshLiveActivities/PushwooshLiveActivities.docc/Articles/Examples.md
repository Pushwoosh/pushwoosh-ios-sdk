# Code Examples

Practical examples for common Live Activities integration scenarios.

## Overview

This guide provides working code examples for typical use cases with PushwooshLiveActivities.

## Delivery Tracking

### Activity Attributes

```swift
import ActivityKit
import PushwooshLiveActivities

struct DeliveryActivityAttributes: PushwooshLiveActivityAttributes {
    var pushwoosh: PushwooshLiveActivityAttributeData

    var orderNumber: String
    var driverName: String
    var deliveryAddress: String

    struct ContentState: PushwooshLiveActivityContentState {
        var pushwoosh: PushwooshLiveActivityContentStateData?

        enum DeliveryStatus: String, Codable {
            case preparing
            case enRoute
            case nearBy
            case delivered
        }

        var status: DeliveryStatus
        var estimatedArrival: Date
        var currentLocation: String
    }
}
```

### Starting Delivery Tracking

```swift
import ActivityKit
import PushwooshLiveActivities

func startDeliveryTracking(orderNumber: String, driverName: String, address: String) {
    guard #available(iOS 16.1, *) else { return }

    let attributes = DeliveryActivityAttributes(
        pushwoosh: .create(activityId: "delivery-\(orderNumber)"),
        orderNumber: orderNumber,
        driverName: driverName,
        deliveryAddress: address
    )

    let contentState = DeliveryActivityAttributes.ContentState(
        pushwoosh: nil,
        status: .preparing,
        estimatedArrival: Date().addingTimeInterval(2700),
        currentLocation: "Restaurant"
    )

    do {
        let activity = try Activity<DeliveryActivityAttributes>.request(
            attributes: attributes,
            contentState: contentState,
            pushType: .token
        )

        print("Delivery tracking started: \(activity.id)")
    } catch {
        print("Failed to start delivery tracking: \(error)")
    }
}
```

### Ending Delivery Tracking

```swift
import ActivityKit
import PushwooshLiveActivities

func endDeliveryTracking() async {
    guard #available(iOS 16.1, *) else { return }

    for activity in Activity<DeliveryActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    Pushwoosh.LiveActivities.stopLiveActivity()
}
```

### Push Payload for Delivery Updates

```json
{
  "aps": {
    "alert": "Your order is on the way!"
  },
  "live_activity": {
    "event": "update",
    "content-state": {
      "status": "enRoute",
      "estimatedArrival": "2024-11-06T15:45:00Z",
      "currentLocation": "Main Street"
    },
    "attributes-type": "DeliveryActivityAttributes"
  }
}
```

## Sports Score Tracking

### Activity Attributes

```swift
import ActivityKit
import PushwooshLiveActivities

struct GameActivityAttributes: PushwooshLiveActivityAttributes {
    var pushwoosh: PushwooshLiveActivityAttributeData

    var homeTeam: String
    var awayTeam: String
    var league: String

    struct ContentState: PushwooshLiveActivityContentState {
        var pushwoosh: PushwooshLiveActivityContentStateData?

        var homeScore: Int
        var awayScore: Int
        var period: String
        var timeRemaining: String
    }
}
```

### Starting Game Tracking

```swift
import ActivityKit
import PushwooshLiveActivities

func startGameTracking(gameId: String, homeTeam: String, awayTeam: String) {
    guard #available(iOS 16.1, *) else { return }

    let attributes = GameActivityAttributes(
        pushwoosh: .create(activityId: "game-\(gameId)"),
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        league: "NBA"
    )

    let contentState = GameActivityAttributes.ContentState(
        pushwoosh: nil,
        homeScore: 0,
        awayScore: 0,
        period: "1st Quarter",
        timeRemaining: "12:00"
    )

    do {
        _ = try Activity<GameActivityAttributes>.request(
            attributes: attributes,
            contentState: contentState,
            pushType: .token
        )
    } catch {
        print("Failed to start game tracking: \(error)")
    }
}
```

### Push Payload for Score Updates

```json
{
  "aps": {
    "alert": "Lakers scored!"
  },
  "live_activity": {
    "event": "update",
    "content-state": {
      "homeScore": 24,
      "awayScore": 18,
      "period": "2nd Quarter",
      "timeRemaining": "8:45"
    },
    "attributes-type": "GameActivityAttributes"
  }
}
```

## Ride Sharing

### Activity Attributes

```swift
import ActivityKit
import PushwooshLiveActivities

struct RideActivityAttributes: PushwooshLiveActivityAttributes {
    var pushwoosh: PushwooshLiveActivityAttributeData

    var driverName: String
    var vehicleModel: String
    var licensePlate: String
    var destination: String

    struct ContentState: PushwooshLiveActivityContentState {
        var pushwoosh: PushwooshLiveActivityContentStateData?

        enum RideStatus: String, Codable {
            case driverEnRoute
            case arrived
            case riding
            case completed
        }

        var status: RideStatus
        var estimatedArrival: Date
        var distanceRemaining: String
    }
}
```

### Starting Ride Tracking

```swift
import ActivityKit
import PushwooshLiveActivities

func startRideTracking(rideId: String, driver: String, vehicle: String, plate: String, destination: String) {
    guard #available(iOS 16.1, *) else { return }

    let attributes = RideActivityAttributes(
        pushwoosh: .create(activityId: "ride-\(rideId)"),
        driverName: driver,
        vehicleModel: vehicle,
        licensePlate: plate,
        destination: destination
    )

    let contentState = RideActivityAttributes.ContentState(
        pushwoosh: nil,
        status: .driverEnRoute,
        estimatedArrival: Date().addingTimeInterval(300),
        distanceRemaining: "0.8 mi"
    )

    do {
        _ = try Activity<RideActivityAttributes>.request(
            attributes: attributes,
            contentState: contentState,
            pushType: .token
        )
    } catch {
        print("Failed to start ride tracking: \(error)")
    }
}
```

## Push-to-Start (iOS 17.2+)

### Setup

```swift
import UIKit
import PushwooshFramework
import PushwooshLiveActivities

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        if #available(iOS 17.2, *) {
            Pushwoosh.LiveActivities.setup(DeliveryActivityAttributes.self)
        }

        return true
    }
}
```

### Push-to-Start Payload

```json
{
  "aps": {
    "alert": "Your order is ready!",
    "content-state": {
      "status": "preparing",
      "estimatedArrival": "2024-11-06T15:30:00Z",
      "currentLocation": "Restaurant"
    },
    "attributes": {
      "orderNumber": "12345",
      "driverName": "John",
      "deliveryAddress": "123 Main St"
    },
    "attributes-type": "DeliveryActivityAttributes",
    "event": "start"
  }
}
```

## Default Mode Examples

### Simple Notification Counter

```swift
import PushwooshLiveActivities

func startNotificationCounter() {
    guard #available(iOS 16.1, *) else { return }

    let attributes = ["type": "notifications"]
    let content = [
        "title": "Notifications",
        "count": 1
    ]

    Pushwoosh.LiveActivities.defaultStart(
        "notification-counter",
        attributes: attributes,
        content: content
    )
}
```

### Push Payload

```json
{
  "aps": {
    "alert": "New notification"
  },
  "live_activity": {
    "event": "update",
    "content-state": {
      "data": {
        "title": "Notifications",
        "count": 5
      }
    },
    "attributes-type": "DefaultLiveActivityAttributes"
  }
}
```

### Timer with Progress

```swift
import PushwooshLiveActivities

func startTimer(duration: Int) {
    guard #available(iOS 16.1, *) else { return }

    let endTime = Date().addingTimeInterval(TimeInterval(duration))

    let attributes = ["timerType": "workout"]
    let content = [
        "title": "Workout Timer",
        "endTime": ISO8601DateFormatter().string(from: endTime),
        "progress": 0.0
    ] as [String : Any]

    Pushwoosh.LiveActivities.defaultStart(
        "workout-timer",
        attributes: attributes,
        content: content
    )
}
```

## Handling Multiple Activities

### Managing Multiple Live Activities

```swift
import ActivityKit
import PushwooshLiveActivities

func listActiveDeliveries() {
    guard #available(iOS 16.1, *) else { return }

    for activity in Activity<DeliveryActivityAttributes>.activities {
        print("Order: \(activity.attributes.orderNumber)")
        print("Status: \(activity.contentState.status)")
        print("Activity ID: \(activity.attributes.pushwoosh.activityId)")
    }
}

func endSpecificDelivery(activityId: String) async {
    guard #available(iOS 16.1, *) else { return }

    for activity in Activity<DeliveryActivityAttributes>.activities {
        if activity.attributes.pushwoosh.activityId == activityId {
            await activity.end(nil, dismissalPolicy: .immediate)
            Pushwoosh.LiveActivities.stopLiveActivity(activityId: activityId)
            break
        }
    }
}
```

## Error Handling

### Handling Activity Request Errors

```swift
import ActivityKit
import PushwooshLiveActivities

func startActivityWithErrorHandling() {
    guard #available(iOS 16.1, *) else {
        print("Live Activities require iOS 16.1+")
        return
    }

    let attributes = DeliveryActivityAttributes(
        pushwoosh: .create(activityId: "delivery-123"),
        orderNumber: "123",
        driverName: "John",
        deliveryAddress: "123 Main St"
    )

    let contentState = DeliveryActivityAttributes.ContentState(
        pushwoosh: nil,
        status: .preparing,
        estimatedArrival: Date().addingTimeInterval(1800),
        currentLocation: "Restaurant"
    )

    do {
        let activity = try Activity<DeliveryActivityAttributes>.request(
            attributes: attributes,
            contentState: contentState,
            pushType: .token
        )
        print("Activity started: \(activity.id)")
    } catch let error as ActivityAuthorizationError {
        print("Authorization error: \(error.localizedDescription)")
    } catch {
        print("Failed to start activity: \(error.localizedDescription)")
    }
}
```

## Next Steps

- <doc:GettingStarted> - Setup guide
- ``PushwooshLiveActivityAttributes`` - Custom attributes protocol
- ``DefaultLiveActivityAttributes`` - Default mode attributes
