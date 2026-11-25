# ``Pushwoosh/VoIP-type.property``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to VoIP push notification functionality.

## Overview

VoIP (Voice over IP) pushes are high-priority notifications for real-time communications:
- Incoming voice/video calls
- Real-time messaging
- Time-critical alerts

## Benefits Over Standard Push

- Wake app in background immediately
- More processing time
- Higher delivery priority
- Works when app is terminated

## Requirements

- The PushwooshVoIP module
- Push Notifications capability and the Voice over IP background mode
- A VoIP Services certificate uploaded to the Pushwoosh Control Panel

The SDK sets up PushKit and CallKit and registers the VoIP token itself at app launch. The app sets the delegate that receives call events.

## Example

Set the delegate and an optional ringtone:

```swift
import PushwooshFramework
import PushwooshVoIP
import CallKit

class AppDelegate: UIResponder, UIApplicationDelegate, PWVoIPCallDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Pushwoosh.VoIP.delegate = self
        Pushwoosh.VoIP.setRingtone("ringtone.caf")
        return true
    }

    func voipDidReceiveIncomingCall(payload: PWVoIPMessage) {
        print("Incoming call from \(payload.callerName)")
    }

    func pwProviderDidReset(_ provider: CXProvider) {}

    func pwProviderDidBegin(_ provider: CXProvider) {}
}
```

## See Also

- ``Pushwoosh/handlePushRegistration(_:)``
