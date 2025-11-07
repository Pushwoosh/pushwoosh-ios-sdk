# Getting Started

Set up iOS Live Activities with push notification updates.

## Installation

@TabNavigator {
    @Tab("Swift Package Manager") {
        In Xcode, use the following URL to add the Pushwoosh dependency:

        ```
        https://github.com/Pushwoosh/Pushwoosh-XCFramework
        ```

        > **Important**: The modules PushwooshFramework, PushwooshCore, PushwooshBridge, and PushwooshLiveActivities are required.
    }

    @Tab("CocoaPods") {
        Add to your Podfile:

        ```ruby
        pod 'PushwooshXCFramework'
        ```

        Then run:

        ```bash
        pod install
        ```
    }
}

## Prerequisites

Before you begin, ensure you have:

- A Pushwoosh account
- A Pushwoosh project set up in your account
- An iOS platform configured in your Pushwoosh project with Token-Based Authentication
- Your Pushwoosh Application Code from the Control Panel
- iOS 16.1+ deployment target (iOS 17.2+ for push-to-start feature)
- PushwooshFramework, PushwooshCore, and PushwooshBridge frameworks integrated in your project
- A Widget Extension target in your Xcode project

> **Important**: Live Activities require iOS 16.1+. Push-to-start functionality requires iOS 17.2+. Only token-based configuration is supported (certificate-based is not supported).

## Step 1: Add Required Capabilities

In Xcode:

1. Select your **app target** (not widget extension)
2. Go to **Signing & Capabilities**
3. Click **+ Capability** and add **Push Notifications**
4. Click **+ Capability** and add **Background Modes**
5. In Background Modes, enable **Remote notifications** checkbox

## Step 2: Configure Info.plist

Add Live Activities support to your app's Info.plist:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

## Step 3: Create Widget Extension

If you don't have a Widget Extension:

1. In Xcode: **File → New → Target**
2. Select **Widget Extension**
3. Enable **Include Live Activity** checkbox
4. Name it (e.g., "MyAppWidgets")
5. Add PushwooshLiveActivities to your Widget Extension target dependencies

## Step 4: Define Activity Attributes

Create a struct conforming to ``PushwooshLiveActivityAttributes``:

```swift
import WidgetKit
import SwiftUI
import ActivityKit
import PushwooshFramework
import PushwooshLiveActivities

struct FoodDeliveryAttributes: PushwooshLiveActivityAttributes {
    public struct ContentState: PushwooshLiveActivityContentState {
        var status: String
        var estimatedTime: String
        var emoji: String
        var pushwoosh: PushwooshLiveActivityContentStateData?
    }

    var orderNumber: String
    var pushwoosh: PushwooshLiveActivityAttributeData
}
```

## Step 5: Create Widget

In your Widget Extension:

```swift
import WidgetKit
import SwiftUI
import ActivityKit

@main
struct FoodDeliveryWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FoodDeliveryAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Order #\(context.attributes.orderNumber)")
                        .font(.headline)
                    Spacer()
                    Text(context.state.emoji)
                        .font(.title)
                }

                Text(context.state.status)
                    .font(.subheadline)

                HStack {
                    Image(systemName: "clock")
                    Text(context.state.estimatedTime)
                }
                .font(.caption)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.emoji)
                        .font(.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.estimatedTime)
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.status)
                        .font(.caption)
                }
            } compactLeading: {
                Text(context.state.emoji)
            } compactTrailing: {
                Text(context.state.estimatedTime)
                    .font(.caption2)
            } minimal: {
                Text(context.state.emoji)
            }
        }
    }
}
```

## Step 6: Initialize in AppDelegate

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

        if #available(iOS 16.1, *) {
            Pushwoosh.LiveActivities.setup(FoodDeliveryAttributes.self)
        }

        return true
    }
}
```

The `setup()` method handles the entire lifecycle of Live Activities:
- Automatically listens for push-to-start token updates (iOS 17.2+)
- Automatically listens for activity token updates
- Registers tokens with Pushwoosh server

## Step 7: Create Live Activity Manager

```swift
import Foundation
import ActivityKit
import UIKit
import PushwooshFramework
import PushwooshLiveActivities

class LiveActivityManager: NSObject, ObservableObject {
    public static let shared = LiveActivityManager()
    private var currentActivity: Activity<FoodDeliveryAttributes>?

    func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }

        do {
            let pushwooshData = PushwooshLiveActivityAttributeData(
                activityId: "order_123"
            )

            let attribute = FoodDeliveryAttributes(
                orderNumber: "1234567",
                pushwoosh: pushwooshData
            )

            let initialState = FoodDeliveryAttributes.ContentState(
                status: "Preparing your meal",
                estimatedTime: "25 min",
                emoji: "👨‍🍳",
                pushwoosh: nil
            )

            let activity = try Activity<FoodDeliveryAttributes>.request(
                attributes: attribute,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token
            )

            self.currentActivity = activity

            Task {
                for await pushToken in activity.pushTokenUpdates {
                    let pushTokenString = pushToken.reduce("") {
                        $0 + String(format: "%02x", $1)
                    }

                    print("Activity push token: \(pushTokenString)")

                    Pushwoosh.LiveActivities.startLiveActivity(
                        token: pushTokenString,
                        activityId: "order_123"
                    )
                }
            }
        } catch {
            print("Start Activity Error: \(error.localizedDescription)")
        }
    }

    func endActivity() async {
        guard let activity = currentActivity else { return }

        await activity.end(nil, dismissalPolicy: .immediate)

        Pushwoosh.LiveActivities.stopLiveActivity(activityId: "order_123")
    }
}
```

## Step 8: Start Activity from UI

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                LiveActivityManager.shared.startActivity()
            }) {
                Text("Start Live Activity")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }

            Button(action: {
                Task {
                    await LiveActivityManager.shared.endActivity()
                }
            }) {
                Text("End Live Activity")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}
```

## Step 9: Send Push Notifications via Pushwoosh API

Use Pushwoosh REST API to send Live Activity updates from your server.

### Start Live Activity (Push-to-Start for iOS 17.2+)

`POST https://api.pushwoosh.com/json/1.3/startLiveActivity`

```json
{
  "request": {
    "application": "YOUR-APP-CODE",
    "auth": "YOUR-API-TOKEN",
    "notifications": [
      {
        "content": "Your order is being prepared!",
        "live_activity": {
          "event": "start",
          "content-state": {
            "status": "Preparing your meal",
            "estimatedTime": "25 min",
            "emoji": "👨‍🍳"
          },
          "attributes-type": "FoodDeliveryAttributes",
          "attributes": {
            "orderNumber": "1234567"
          }
        },
        "live_activity_id": "order_123",
        "filter_code": "user_segment_code"
      }
    ]
  }
}
```

**Targeting Options:**
- `filter_code`: Target specific user segment
- `devices`: Array of push tokens or HWIDs (max 1000)
- `users`: Array of User IDs (max 1000)

### Update Live Activity

`POST https://api.pushwoosh.com/json/1.3/updateLiveActivity`

```json
{
  "request": {
    "application": "YOUR-APP-CODE",
    "auth": "YOUR-API-TOKEN",
    "notifications": [
      {
        "live_activity": {
          "event": "update",
          "content-state": {
            "status": "On the way",
            "estimatedTime": "10 min",
            "emoji": "🚚"
          },
          "stale-date": 1234567890
        },
        "live_activity_id": "order_123"
      }
    ]
  }
}
```

**Optional Parameters:**
- `stale-date`: Unix timestamp when content becomes stale
- `dismissal-date`: Unix timestamp when to dismiss (use with "end" event)

### End Live Activity

`POST https://api.pushwoosh.com/json/1.3/updateLiveActivity`

```json
{
  "request": {
    "application": "YOUR-APP-CODE",
    "auth": "YOUR-API-TOKEN",
    "notifications": [
      {
        "live_activity": {
          "event": "end",
          "dismissal-date": 1234567890
        },
        "live_activity_id": "order_123"
      }
    ]
  }
}
```

**Note:** For push-to-start functionality (iOS 17.2+), the `setup()` method automatically handles token registration. No additional code is needed in the app.

## Available SDK Methods

The PushwooshLiveActivities module provides the following methods:

### Setup Methods

```swift
// Setup with custom attributes (iOS 16.1+)
static func setup<Attributes: PushwooshLiveActivityAttributes>(
    _ activityType: Attributes.Type
)

// Setup with default attributes (iOS 16.1+)
static func defaultSetup()
```

### Token Management

> **Important**: These methods are only needed if you are **NOT** using `setup()` or `defaultSetup()`. The setup methods automatically manage all token registration and lifecycle. Use these methods only for manual token management scenarios.

```swift
// Send push-to-start token (iOS 17.2+)
static func sendPushToStartLiveActivity(token: String)
static func sendPushToStartLiveActivity(
    token: String,
    completion: @escaping (Error?) -> Void
)

// Register activity token
static func startLiveActivity(token: String, activityId: String)
static func startLiveActivity(
    token: String,
    activityId: String,
    completion: @escaping (Error?) -> Void
)
```

### Activity Lifecycle

```swift
// Stop all activities
static func stopLiveActivity()
static func stopLiveActivity(completion: @escaping (Error?) -> Void)

// Stop specific activity
static func stopLiveActivity(activityId: String)
static func stopLiveActivity(
    activityId: String,
    completion: @escaping (Error?) -> Void
)
```

### Default Mode Methods

> **Important**: Use `defaultStart()` only when you have called `defaultSetup()` during app initialization. This method creates a Live Activity using ``DefaultLiveActivityAttributes`` structure.

```swift
// Start activity with default attributes (iOS 16.1+)
// Requires defaultSetup() to be called first
static func defaultStart(
    _ activityId: String,
    attributes: [String: Any],
    content: [String: Any]
)
```

**Example:**
```swift
// In AppDelegate
if #available(iOS 16.1, *) {
    Pushwoosh.LiveActivities.defaultSetup()
}

// Later in your code
Pushwoosh.LiveActivities.defaultStart(
    "order_123",
    attributes: ["restaurantName": "Burger House"],
    content: ["status": "Preparing", "estimatedTime": "25 min"]
)
```

## REST API Integration

Pushwoosh provides REST API endpoints for remote Live Activities management:

### Start Live Activity
`POST https://api.pushwoosh.com/json/1.3/startLiveActivity`

Required parameters:
- `application`: Pushwoosh application code
- `auth`: API access token
- `notifications`: Array containing Live Activity data

### Update Live Activity
`POST https://api.pushwoosh.com/json/1.3/updateLiveActivity`

Required parameters:
- `application`: Pushwoosh application code
- `auth`: API access token
- `notifications`: Array with `event` ("update" or "end") and `content-state`

For complete REST API documentation, see [iOS Live Activities API Reference](https://docs.pushwoosh.com/developer/api-reference/ios-live-activities-api/).

## Important Notes

- **Activity ID**: Must be unique per user segment for proper targeting
- **Token-based only**: Certificate-based push configuration is not supported
- **Physical device**: Live Activities work on physical devices (Simulator support available iOS 16.4+)
- **Permissions**: User must have notifications enabled
- **API vs SDK**: Use SDK methods for app-side management, REST API for server-side control

## Testing

1. Build and run your app on a physical device running iOS 16.1+
2. Tap "Start Live Activity" button
3. Check console for activity token
4. Send test push from Pushwoosh Control Panel
5. Observe Live Activity update on Lock Screen and Dynamic Island

## Next Steps

- <doc:Examples> - Code examples for common use cases
- ``PushwooshLiveActivityAttributes`` - Custom attributes protocol reference
- ``DefaultLiveActivityAttributes`` - Default mode attributes reference
