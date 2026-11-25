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
        print("Incoming call: \(payload.callerName)")
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
        guard let uuid = UUID(uuidString: payload.uuid) else {
            return
        }

        let callInfo = CallInfo(
            uuid: uuid,
            callerName: payload.callerName,
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

    func getAllCallUUIDs() -> [UUID] {
        return Array(activeCalls.keys)
    }
}

extension AppDelegate: PWVoIPCallDelegate {

    func voipDidReceiveIncomingCall(payload: PushwooshVoIP.PWVoIPMessage) {
        CallManager.shared.storeCall(payload)
    }
}
```

### Answer Call

The SDK fulfills the CallKit action after the delegate returns, so the delegate only starts the call. Configure audio when CallKit activates the audio session:

```swift
extension AppDelegate: PWVoIPCallDelegate {

    func answerCall(_ provider: CXProvider, perform action: CXAnswerCallAction, voipMessage: PWVoIPMessage?) {
        guard let callInfo = CallManager.shared.getCall(uuid: action.callUUID) else {
            return
        }

        startCallWithPeer(callInfo.callerName)
    }

    func activatedAudioSession(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        try? audioSession.setCategory(.playAndRecord, mode: .voiceChat)
        startAudio()
    }

    private func startCallWithPeer(_ peerName: String) {
        print("Starting call with \(peerName)")
    }

    private func startAudio() {
        print("Audio started")
    }
}
```

### End Call

```swift
extension AppDelegate: PWVoIPCallDelegate {

    func endCall(_ provider: CXProvider, perform action: CXEndCallAction, voipMessage: PWVoIPMessage?) {
        endCallSession(action.callUUID)
        CallManager.shared.removeCall(uuid: action.callUUID)
    }

    func deactivatedAudioSession(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        stopAudio()
    }

    private func endCallSession(_ uuid: UUID) {
        print("Ending call: \(uuid)")
    }

    private func stopAudio() {
        print("Audio stopped")
    }
}
```

## Call Controls

### Mute/Unmute

```swift
extension AppDelegate: PWVoIPCallDelegate {

    func mutedCall(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        if action.isMuted {
            disableMicrophone()
        } else {
            enableMicrophone()
        }
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

    func heldCall(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        if action.isOnHold {
            pauseCall(action.callUUID)
        } else {
            resumeCall(action.callUUID)
        }
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

CallKit ends every call and deactivates the audio session on reset; release your own call state:

```swift
extension AppDelegate: PWVoIPCallDelegate {

    func pwProviderDidReset(_ provider: CXProvider) {
        print("CallKit provider reset")

        for uuid in CallManager.shared.getAllCallUUIDs() {
            endCallSession(uuid)
            CallManager.shared.removeCall(uuid: uuid)
        }

        print("All calls terminated")
    }
}
```

## Next Steps

- <doc:GettingStarted> - Quick start guide
- ``PWVoIPCallDelegate`` - Full delegate reference
