//
//  PWVoIPExtension.swift
//  PushwooshVoIP
//
//  Created by André on 6.5.25..
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore
import PushwooshBridge
import CallKit
import AVFoundation

public extension PWVoIP {
    /// The delegate object that receives VoIP call events and CallKit callbacks.
    ///
    /// Set this property to an object conforming to `PWVoIPCallDelegate` protocol to receive notifications
    /// about incoming calls, CallKit interactions, and call lifecycle events.
    ///
    /// - Note: The delegate is stored as a weak reference. Ensure your delegate object has a strong reference elsewhere.
    @available(iOS 14.0, *)
    static var delegate: AnyObject? {
        get { PushwooshVoIPImplementation.delegate }
        set { PushwooshVoIPImplementation.delegate = newValue }
    }

    /// Initializes the VoIP functionality with call parameters and ringtone settings.
    ///
    /// Call this method to configure VoIP support before registering for VoIP push notifications.
    /// The configuration determines how incoming calls are presented in CallKit UI.
    ///
    /// - Parameter supportVideo: Set to `true` to enable video call support. Video calls display with video call icons in CallKit.
    /// - Parameter ringtoneSound: The name of the sound file to play for incoming calls (e.g., "ringtone.caf").
    ///                           The file must be included in your app bundle.
    /// - Parameter handleTypes: The default handle type for caller identification. Use `PWVoIPHandleType.rawValue`.
    ///
    /// - Note: This method should be called once during app initialization, before receiving VoIP pushes.
    @available(iOS 14.0, *)
    static func initializeVoIP(_ supportVideo: Bool,
                               ringtoneSound: String,
                               handleTypes: Int) {
        PushwooshVoIPImplementation.initializeVoIP(supportVideo,
                                                   ringtoneSound: ringtoneSound,
                                                   handleTypes: handleTypes)
    }

    /// Registers the VoIP push token with Pushwoosh servers.
    ///
    /// Call this method with the token received from `PKPushRegistry` delegate callback.
    /// The token is sent to Pushwoosh backend to enable VoIP push notification delivery to this device.
    ///
    /// - Parameter token: The VoIP push token data received from PushKit framework.
    ///
    /// - Note: The token registration result is reported via `voipDidRegisterTokenSuccessfully()` or
    ///         `voipDidFailToRegisterToken(error:)` delegate methods.
    @available(iOS 14.0, *)
    static func setVoIPToken(_ token: Data) {
        PushwooshVoIPImplementation.setVoIPToken(token)
    }

    /// Sets the Pushwoosh VoIP application code.
    ///
    /// Configure the VoIP-specific application code to use for registering VoIP push tokens.
    /// This allows using a separate Pushwoosh application for VoIP notifications if needed.
    ///
    /// - Parameter voipAppId: The Pushwoosh application code for VoIP notifications (e.g., "XXXXX-XXXXX").
    ///
    /// - Note: If not set, the SDK uses the main Pushwoosh application code configured via `Pushwoosh.sharedInstance().setAppCode()`.
    @available(iOS 14.0, *)
    static func setPushwooshVoIPAppId(_ voipAppId: String) {
        PushwooshVoIPImplementation.setPushwooshVoIPAppId(voipAppId)
    }

    /// Sets the timeout duration for incoming call notifications.
    ///
    /// Configures how long the incoming call UI remains active before automatically timing out.
    /// When the timeout expires, the CallKit UI is automatically dismissed.
    ///
    /// - Parameter timeout: The timeout duration in seconds. Default is 30 seconds.
    ///
    /// - Note: Set this before initializing VoIP to ensure the timeout applies to all incoming calls.
    @available(iOS 14.0, *)
    static func setIncomingCallTimeout(_ timeout: TimeInterval) {
        PushwooshVoIPImplementation.setIncomingCallTimeout(timeout)
    }
}

/// Delegate protocol for receiving VoIP call events and CallKit callbacks.
///
/// Implement this protocol to handle VoIP push notifications, CallKit interactions, and call lifecycle events.
/// Set your delegate implementation via `PWVoIP.delegate` to receive these callbacks.
@objc public protocol PWVoIPCallDelegate: NSObjectProtocol {

    /// Called when VoIP token is successfully registered with Pushwoosh servers.
    ///
    /// This method is invoked after the VoIP push token has been successfully sent to Pushwoosh backend
    /// and the device is ready to receive VoIP push notifications.
    ///
    /// - Note: This is an optional delegate method. Use it to update your UI or log successful registration.
    @objc optional func voipDidRegisterTokenSuccessfully()

    /// Called when VoIP token registration fails.
    ///
    /// This method is invoked when the SDK fails to register the VoIP push token with Pushwoosh servers.
    /// Common causes include network errors, invalid app configuration, or server issues.
    ///
    /// - Parameter error: The error that occurred during registration. Check `error.localizedDescription` for details.
    /// - Note: This is an optional delegate method. Implement it to handle registration failures and inform the user.
    @objc optional func voipDidFailToRegisterToken(error: Error)

    /// Called when a VoIP push notification arrives.
    ///
    /// This is the main entry point for handling incoming VoIP calls. The method is invoked when a VoIP push
    /// is received from Pushwoosh servers. Use the payload information to display caller details and handle
    /// call setup in your application.
    ///
    /// - Parameter payload: The VoIP message containing call information such as caller name, handle type, and video support.
    /// - Important: This is a required delegate method. You must implement it to handle incoming VoIP calls.
    @objc func voipDidReceiveIncomingCall(payload: PWVoIPMessage)

    /// Called when incoming call is successfully reported to CallKit.
    ///
    /// This method is invoked after the SDK successfully reports the incoming call to CallKit framework,
    /// and the system incoming call UI is displayed to the user.
    ///
    /// - Parameter voipMessage: The VoIP message that was successfully reported to CallKit.
    /// - Note: This is an optional delegate method. Use it to track successful CallKit integration or update your analytics.
    @objc optional func voipDidReportIncomingCallSuccessfully(voipMessage: PWVoIPMessage)

    /// Called when reporting incoming call to CallKit fails.
    ///
    /// This method is invoked when the SDK fails to report the incoming call to CallKit framework.
    /// Common causes include CallKit permission issues, invalid call parameters, or system restrictions.
    ///
    /// - Parameter error: The error that occurred while reporting to CallKit. Check `error.localizedDescription` for details.
    /// - Note: This is an optional delegate method. Implement it to handle CallKit reporting failures.
    @objc optional func voipDidFailToReportIncomingCall(error: Error)

    /// Called when a call is remotely cancelled via VoIP push before the user answers.
    ///
    /// This method is invoked when the remote party cancels their outgoing call before the local user has a chance to answer.
    /// The SDK automatically dismisses the CallKit incoming call UI when this occurs.
    ///
    /// To enable call cancellation, include these fields in your VoIP push payload:
    /// - `callId` - A unique server-provided identifier for the call
    /// - `cancelCall` - Set to `true` for cancellation requests
    ///
    /// The SDK matches cancellation requests to active calls using the `callId` field. When a cancellation push is received,
    /// CallKit UI is automatically dismissed with `CXCallEndedReason.remoteEnded`.
    ///
    /// - Parameter voipMessage: The VoIP message containing call information. Use `voipMessage.callId` to identify which call was cancelled.
    /// - Note: This is an optional delegate method. If not implemented, the SDK will still automatically dismiss the CallKit UI.
    /// - Important: Cancellation only works for calls that haven't been answered yet. Once answered, cancellation requests are ignored.
    @objc optional func voipDidCancelCall(voipMessage: PWVoIPMessage)

    /// Called when a call cancellation attempt fails.
    ///
    /// This method is invoked when the SDK receives a cancellation request but cannot cancel the call.
    /// Common failure reasons include:
    /// - No active call found with the provided `callId`
    /// - The call has already been answered by the user
    /// - The call has already ended
    /// - Missing `callId` in the cancellation payload
    ///
    /// - Parameter callId: The call identifier from the cancellation request, or nil if not provided.
    /// - Parameter reason: A human-readable description of why the cancellation failed.
    /// - Note: This is an optional delegate method. Implement it to track cancellation failures for debugging or analytics.
    @objc optional func voipDidFailToCancelCall(callId: String?, reason: String)

    /// Called when user initiates an outgoing call.
    ///
    /// This method is invoked when the user starts an outgoing call through CallKit. Implement this method
    /// to set up your call session and establish the connection with the remote party.
    ///
    /// - Parameter provider: The CallKit provider managing the call.
    /// - Parameter action: The action containing call details. Call `action.fulfill()` when setup completes successfully,
    ///                     or `action.fail()` if setup fails.
    /// - Note: This is an optional delegate method. Implement it if your app supports outgoing calls.
    @objc optional func startCall(_ provider: CXProvider, perform action: CXStartCallAction)

    /// Called when user ends a call.
    ///
    /// This method is invoked when the user terminates an active call through CallKit UI (by tapping the end call button).
    /// Use this callback to tear down your call session, release resources, and notify the remote party.
    ///
    /// - Parameter provider: The CallKit provider managing the call.
    /// - Parameter action: The action containing call details. Call `action.fulfill()` when teardown completes.
    /// - Parameter voipMessage: The original VoIP message associated with this call, if available.
    /// - Note: This is an optional delegate method. The SDK automatically handles cleanup, but implement this to perform custom teardown logic.
    @objc optional func endCall(_ provider: CXProvider, perform action: CXEndCallAction, voipMessage: PWVoIPMessage?)

    /// Called when user answers an incoming call.
    ///
    /// This method is invoked when the user accepts an incoming call through CallKit UI (by swiping to answer or tapping accept).
    /// Use this callback to establish the call connection, configure audio session, and start media streaming.
    ///
    /// - Parameter provider: The CallKit provider managing the call.
    /// - Parameter action: The action containing call details. Call `action.fulfill()` when connection is established.
    /// - Parameter voipMessage: The original VoIP message containing caller information and call parameters.
    /// - Note: This is an optional delegate method. Implement it to handle call answer logic and establish the communication channel.
    @objc optional func answerCall(_ provider: CXProvider, perform action: CXAnswerCallAction, voipMessage: PWVoIPMessage?)

    /// Called when user mutes or unmutes the call.
    ///
    /// This method is invoked when the user toggles the mute button in CallKit UI. Implement this method
    /// to mute or unmute the local audio stream accordingly.
    ///
    /// - Parameter provider: The CallKit provider managing the call.
    /// - Parameter action: The action containing mute state. Use `action.isMuted` to determine the new mute state.
    ///                     Call `action.fulfill()` after updating the audio state.
    /// - Note: This is an optional delegate method. Implement it to control microphone muting during the call.
    @objc optional func mutedCall(_ provider: CXProvider, perform action: CXSetMutedCallAction)

    /// Called when user puts the call on hold or resumes it.
    ///
    /// This method is invoked when the user toggles the hold button in CallKit UI. Implement this method
    /// to pause or resume media streaming and notify the remote party of the hold state.
    ///
    /// - Parameter provider: The CallKit provider managing the call.
    /// - Parameter action: The action containing hold state. Use `action.isOnHold` to determine the new hold state.
    ///                     Call `action.fulfill()` after updating the call state.
    /// - Note: This is an optional delegate method. Implement it if your app supports call hold functionality.
    @objc optional func heldCall(_ provider: CXProvider, perform action: CXSetHeldCallAction)

    /// Called when user plays DTMF tone during the call.
    ///
    /// This method is invoked when the user presses a keypad digit in CallKit UI during an active call.
    /// Implement this method to send DTMF tones to the remote party for interactive voice response systems.
    ///
    /// - Parameter provider: The CallKit provider managing the call.
    /// - Parameter action: The action containing the digit. Use `action.digits` to get the pressed digit.
    ///                     Call `action.fulfill()` after playing the tone.
    /// - Note: This is an optional delegate method. Implement it if your app supports DTMF tone generation.
    @objc optional func playDTMF(_ provider: CXProvider, perform action: CXPlayDTMFCallAction)

    /// Called when the CallKit provider resets.
    ///
    /// This method is invoked when CallKit provider encounters a critical error or system reset.
    /// When this occurs, all active calls are terminated and you should clean up any call-related resources.
    ///
    /// - Parameter provider: The CallKit provider that was reset.
    /// - Important: This is a required delegate method. Always implement it to handle provider resets and perform cleanup.
    @objc func pwProviderDidReset(_ provider: CXProvider)

    /// Called when the CallKit provider is ready to handle calls.
    ///
    /// This method is invoked when the CallKit provider has been initialized and is ready to manage calls.
    /// Use this callback to perform any initialization that depends on CallKit being available.
    ///
    /// - Parameter provider: The CallKit provider that is now active.
    /// - Important: This is a required delegate method. Implement it to track CallKit provider lifecycle.
    @objc func pwProviderDidBegin(_ provider: CXProvider)

    /// Called to provide the call controller instance.
    ///
    /// This method is invoked to give your app access to the CXCallController instance managed by the SDK.
    /// Use the controller to request call actions programmatically, such as ending calls or updating call state.
    ///
    /// - Parameter controller: The CXCallController instance for managing call actions.
    /// - Note: This is an optional delegate method. Implement it if you need direct access to the call controller.
    @objc optional func returnedCallController(_ controller: CXCallController)

    /// Called to provide the CallKit provider instance.
    ///
    /// This method is invoked to give your app access to the CXProvider instance managed by the SDK.
    /// Use the provider to configure CallKit settings or handle provider-level operations.
    ///
    /// - Parameter provider: The CXProvider instance for managing CallKit integration.
    /// - Note: This is an optional delegate method. Implement it if you need direct access to the CallKit provider.
    @objc optional func returnedProvider(_ provider: CXProvider)

    /// Called when audio session is activated.
    ///
    /// This method is invoked when CallKit activates the audio session for a call. Use this callback to configure
    /// audio routing, start audio processing, or begin media playback.
    ///
    /// - Parameter provider: The CallKit provider managing the call.
    /// - Parameter audioSession: The activated AVAudioSession instance. Configure audio settings as needed.
    /// - Note: This is an optional delegate method. Implement it to manage audio session activation and configure audio routing.
    @objc optional func activatedAudioSession(_ provider: CXProvider, didActivate audioSession: AVAudioSession)

    /// Called when audio session is deactivated.
    ///
    /// This method is invoked when CallKit deactivates the audio session after a call ends. Use this callback to
    /// stop audio processing and release audio resources.
    ///
    /// - Parameter provider: The CallKit provider managing the call.
    /// - Parameter audioSession: The deactivated AVAudioSession instance.
    /// - Note: This is an optional delegate method. Implement it to handle audio session deactivation and cleanup audio resources.
    @objc optional func deactivatedAudioSession(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession)
}
