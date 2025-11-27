# ``Pushwoosh/VoIP``

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

- PushKit framework
- VoIP entitlement
- CallKit integration (recommended)

## Example

Register for VoIP pushes:

```swift
import PushKit

class VoIPHandler: NSObject, PKPushRegistryDelegate {

    let voipRegistry = PKPushRegistry(queue: .main)

    func setupVoIP() {
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
    }

    func pushRegistry(_ registry: PKPushRegistry,
                     didUpdate pushCredentials: PKPushCredentials,
                     for type: PKPushType) {
        Pushwoosh.VoIP.handleVoIPPushRegistration(pushCredentials.token)
    }

    func pushRegistry(_ registry: PKPushRegistry,
                     didReceiveIncomingPushWith payload: PKPushPayload,
                     for type: PKPushType,
                     completion: @escaping () -> Void) {
        handleIncomingCall(payload: payload.dictionaryPayload)
        completion()
    }
}
```

## See Also

- ``Pushwoosh/handlePushRegistration(_:)``
