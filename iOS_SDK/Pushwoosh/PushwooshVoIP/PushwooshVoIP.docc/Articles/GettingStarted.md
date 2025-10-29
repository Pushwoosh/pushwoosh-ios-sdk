# Getting Started

Set up VoIP push notifications with CallKit in your iOS app.

## Installation

@TabNavigator {
    @Tab("Swift Package Manager") {
        Add PushwooshVoIP as a dependency to your Package.swift:

        ```swift
        dependencies: [
            .package(url: "https://github.com/Pushwoosh/Pushwoosh-XCFramework", from: "6.10.0")
        ]
        ```

        Select the required modules in your target:

        ![Choose package products: PushwooshBridge, PushwooshCore, PushwooshFramework, and PushwooshVoIP](ios-voip-1.png)

        > **Important**: The modules PushwooshFramework, PushwooshCore, PushwooshBridge, and PushwooshVoIP are required.
    }

    @Tab("CocoaPods") {
        Add to your Podfile:

        ```ruby
        pod 'PushwooshXCFramework'
        pod 'PushwooshXCFramework/PushwooshVoIP'
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
- An iOS platform configured in your Pushwoosh project. We recommend using the Token-Based Authentication configuration as the simplest approach
- A separate VoIP Application created in your Pushwoosh project
- Your Pushwoosh Application Code and VoIP Application Code from the Control Panel
- VoIP Services Certificate (.p12) created in Apple Developer Portal
- iOS 14.0+ deployment target
- PushwooshFramework, PushwooshCore, and PushwooshBridge frameworks integrated in your project

> **Important**: VoIP Applications are separate from regular push applications in Pushwoosh. You must create a dedicated VoIP Application and use its Application Code.

## Step 1: Add Required Capabilities

In Xcode:

1. Select your target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** and add **Push Notifications**
4. Click **+ Capability** and add **Background Modes**
5. In Background Modes, enable **Remote notifications** checkbox
6. In Background Modes, enable **Voice over IP** checkbox

![Required capabilities: Push Notifications and Background Modes with Remote notifications and Voice over IP enabled](ios-voip-2.png)

## Step 2: Initialize the Module

Initialize in `application(_:didFinishLaunchingWithOptions:)`:

```swift
import UIKit
import PushwooshFramework
import PushwooshVoIP
import CallKit
import PushKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate, PWVoIPCallDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        Pushwoosh.VoIP.initializeVoIP(true, ringtoneSound: "mySound.caf", handleTypes: 1)
        Pushwoosh.VoIP.setPushwooshVoIPAppId("YOUR-VOIP-APP-CODE")
        Pushwoosh.VoIP.delegate = self

        return true
    }

    // MARK: - Required PWVoIPCallDelegate Callbacks

    func voipDidReceiveIncomingCall(payload: PushwooshVoIP.PWVoIPMessage) {
        // Handle incoming VoIP push
    }

    func pwProviderDidReset(_ provider: CXProvider) {
        // Handle provider reset
    }

    func pwProviderDidBegin(_ provider: CXProvider) {
        // Handle provider activation
    }
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `supportVideo` | `Bool` | Enable video calling in CallKit UI |
| `ringtoneSound` | `String?` | Custom ringtone filename from app bundle (e.g., `"mySound.caf"`). Pass `nil` for system default |
| `handleTypes` | `Int` | Caller ID display format:<br>• `1` – Generic (usernames, custom IDs)<br>• `2` – Phone Number (formatted phone numbers)<br>• `3` – Email (email addresses) |

## Step 3: Delegate Methods

The ``PWVoIPCallDelegate`` protocol provides callbacks for VoIP events:

| Method | Description |
|--------|-------------|
| `voipDidReceiveIncomingCall(payload:)` | Called when VoIP push arrives with call information |
| `pwProviderDidReset(_:)` | Called when CallKit provider resets (end all active calls here) |
| `pwProviderDidBegin(_:)` | Called when CallKit provider is ready |

## Step 4: Upload VoIP Certificate

1. Create VoIP Services Certificate in Apple Developer Portal
2. Export as .p12 file
3. In Pushwoosh Control Panel, go to your VoIP Application settings
4. Upload the .p12 certificate

> **Important**: VoIP pushes require production gateway certificate. Sandbox certificates are not supported.

## Testing

VoIP pushes only work on physical devices. Simulator is not supported.

Build and run your app on a physical device, then send a test VoIP push from the Pushwoosh Control Panel.

## Next Steps

- <doc:Examples> - Code examples for common use cases
- ``PWVoIPCallDelegate`` - Full protocol reference
