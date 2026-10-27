# Code Examples

Practical examples for common VoIP integration scenarios.

## Overview

This guide provides working code examples for typical use cases with PushwooshVoIP module.

## Basic Setup

### Minimal Configuration

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

        Pushwoosh.VoIP.delegate = self

        return true
    }

    func voipDidReceiveIncomingCall(payload: PushwooshVoIP.PWVoIPMessage) {
        print("Incoming call: \(payload.callerName ?? "Unknown")")
    }

    func pwProviderDidReset(_ provider: CXProvider) {
        print("Provider reset")
    }

    func pwProviderDidBegin(_ provider: CXProvider) {
        print("Provider ready")
    }
}
```

## Handling Incoming Calls

### Store Call Information

```swift
class CallManager {
    static let shared = CallManager()

    private var activeCalls: [UUID: CallInfo] = [:]

    struct CallInfo {
        let uuid: UUID
        let callerName: String
        let hasVideo: Bool
        let timestamp: Date
    }

    func storeCall(_ payload: PWVoIPMessage) {
        guard let uuidString = payload.uuid,
              let uuid = UUID(uuidString: uuidString) else {
            return
        }

        let callInfo = CallInfo(
            uuid: uuid,
            callerName: payload.callerName ?? "Unknown",
            hasVideo: payload.hasVideo,
            timestamp: Date()
        )

        activeCalls[uuid] = callInfo
    }

    func getCall(uuid: UUID) -> CallInfo? {
        return activeCalls[uuid]
    }

    func removeCall(uuid: UUID) {
        activeCalls.removeValue(forKey: uuid)
    }
}

extension AppDelegate: PWVoIPCallDelegate {

    func voipDidReceiveIncomingCall(payload: PushwooshVoIP.PWVoIPMessage) {
        CallManager.shared.storeCall(payload)
    }
}
```

### Answer Call

```swift
extension AppDelegate: PWVoIPCallDelegate {

    func pwPerform(_ action: CXAnswerCallAction) {
        let callUUID = action.callUUID

        guard let callInfo = CallManager.shared.getCall(uuid: callUUID) else {
            action.fail()
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat)
            try audioSession.setActive(true)
        } catch {
            action.fail()
            return
        }

        startCallWithPeer(callInfo.callerName)
        action.fulfill()
    }

    private func startCallWithPeer(_ peerName: String) {
        print("Starting call with \(peerName)")
    }
}
```

### End Call

```swift
extension AppDelegate: PWVoIPCallDelegate {

    func pwPerform(_ action: CXEndCallAction) {
        let callUUID = action.callUUID

        endCallSession(callUUID)
        CallManager.shared.removeCall(uuid: callUUID)

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        action.fulfill()
    }

    private func endCallSession(_ uuid: UUID) {
        print("Ending call: \(uuid)")
    }
}
```

## Call Controls

### Mute/Unmute

```swift
extension AppDelegate: PWVoIPCallDelegate {

    func pwPerform(_ action: CXSetMutedCallAction) {
        let isMuted = action.isMuted

        if isMuted {
            disableMicrophone()
        } else {
            enableMicrophone()
        }

        action.fulfill()
    }

    private func disableMicrophone() {
        print("Microphone disabled")
    }

    private func enableMicrophone() {
        print("Microphone enabled")
    }
}
```

### Hold/Resume

```swift
extension AppDelegate: PWVoIPCallDelegate {

    func pwPerform(_ action: CXSetHeldCallAction) {
        let callUUID = action.callUUID
        let isOnHold = action.isOnHold

        if isOnHold {
            pauseCall(callUUID)
        } else {
            resumeCall(callUUID)
        }

        action.fulfill()
    }

    private func pauseCall(_ uuid: UUID) {
        print("Call paused: \(uuid)")
    }

    private func resumeCall(_ uuid: UUID) {
        print("Call resumed: \(uuid)")
    }
}
```

## Token Management

### Monitor Token Registration

The SDK gets the VoIP token from PushKit and registers it with Pushwoosh under your main Application Code. Both callbacks are optional:

```swift
extension AppDelegate: PWVoIPCallDelegate {

    func voipDidRegisterTokenSuccessfully() {
        print("VoIP token registered")
    }

    func voipDidFailToRegisterToken(error: Error) {
        print("VoIP token registration failed: \(error.localizedDescription)")
    }
}
```

## Video Calls

### Enable Video Support

A call is shown as a video call when the push payload has `"video": true`. Check it in the delegate:

```swift
extension AppDelegate: PWVoIPCallDelegate {

    func voipDidReceiveIncomingCall(payload: PushwooshVoIP.PWVoIPMessage) {
        if payload.hasVideo {
            print("Incoming VIDEO call")
            prepareVideoCallUI()
        } else {
            print("Incoming AUDIO call")
            prepareAudioCallUI()
        }

        CallManager.shared.storeCall(payload)
    }

    private func prepareVideoCallUI() {
        print("Preparing video call UI")
    }

    private func prepareAudioCallUI() {
        print("Preparing audio call UI")
    }
}
```

## Handle Types

The caller ID format comes from the `handleType` field of the push payload and is available as `payload.handleType`:

| `handleType` | ``PWVoIPHandleType`` | Format |
|---|---|---|
| `1` (default) | `.generic` | Usernames, custom IDs |
| `2` | `.phoneNumber` | Phone numbers |
| `3` | `.email` | Email addresses |

## Error Handling

### Handle Provider Reset

```swift
extension AppDelegate: PWVoIPCallDelegate {

    func pwProviderDidReset(_ provider: CXProvider) {
        print("CallKit provider reset")

        let allCallUUIDs = CallManager.shared.getAllCallUUIDs()
        for uuid in allCallUUIDs {
            endCallSession(uuid)
            CallManager.shared.removeCall(uuid: uuid)
        }

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false)

        print("All calls terminated")
    }
}
```

## Next Steps

- <doc:GettingStarted> - Quick start guide
- ``PWVoIPCallDelegate`` - Full delegate reference
