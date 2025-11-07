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
    @available(iOS 14.0, *)
    static var delegate: AnyObject? {
        get { PushwooshVoIPImplementation.delegate }
        set { PushwooshVoIPImplementation.delegate = newValue }
    }
    
    @available(iOS 14.0, *)
    static func initializeVoIP(_ supportVideo: Bool,
                               ringtoneSound: String,
                               handleTypes: Int) {
        PushwooshVoIPImplementation.initializeVoIP(supportVideo,
                                                   ringtoneSound: ringtoneSound,
                                                   handleTypes: handleTypes)
    }
    
    @available(iOS 14.0, *)
    static func setVoIPToken(_ token: Data) {
        PushwooshVoIPImplementation.setVoIPToken(token)
    }
    
    @available(iOS 14.0, *)
    static func setPushwooshVoIPAppId(_ voipAppId: String) {
        PushwooshVoIPImplementation.setPushwooshVoIPAppId(voipAppId)
    }

    @available(iOS 14.0, *)
    static func setIncomingCallTimeout(_ timeout: TimeInterval) {
        PushwooshVoIPImplementation.setIncomingCallTimeout(timeout)
    }
}

/// Delegate protocol for receiving VoIP call events and CallKit callbacks.
@objc public protocol PWVoIPCallDelegate: NSObjectProtocol {

    /// Called when VoIP token is successfully registered with Pushwoosh servers.
    @objc optional func voipDidRegisterTokenSuccessfully()

    /// Called when VoIP token registration fails.
    @objc optional func voipDidFailToRegisterToken(error: Error)

    /// Called when a VoIP push notification arrives.
    @objc func voipDidReceiveIncomingCall(payload: PWVoIPMessage)

    /// Called when incoming call is successfully reported to CallKit.
    @objc optional func voipDidReportIncomingCallSuccessfully(voipMessage: PWVoIPMessage)

    /// Called when reporting incoming call to CallKit fails.
    @objc optional func voipDidFailToReportIncomingCall(error: Error)

    /// Called when user initiates an outgoing call.
    @objc optional func startCall(_ provider: CXProvider, perform action: CXStartCallAction)

    /// Called when user ends a call.
    @objc optional func endCall(_ provider: CXProvider, perform action: CXEndCallAction, voipMessage: PWVoIPMessage?)

    /// Called when user answers an incoming call.
    @objc optional func answerCall(_ provider: CXProvider, perform action: CXAnswerCallAction, voipMessage: PWVoIPMessage?)

    /// Called when user mutes or unmutes the call.
    @objc optional func mutedCall(_ provider: CXProvider, perform action: CXSetMutedCallAction)

    /// Called when user puts the call on hold or resumes it.
    @objc optional func heldCall(_ provider: CXProvider, perform action: CXSetHeldCallAction)

    /// Called when user plays DTMF tone during the call.
    @objc optional func playDTMF(_ provider: CXProvider, perform action: CXPlayDTMFCallAction)

    /// Called when the CallKit provider resets.
    @objc func pwProviderDidReset(_ provider: CXProvider)

    /// Called when the CallKit provider is ready to handle calls.
    @objc func pwProviderDidBegin(_ provider: CXProvider)

    /// Called to provide the call controller instance.
    @objc optional func returnedCallController(_ controller: CXCallController)

    /// Called to provide the CallKit provider instance.
    @objc optional func returnedProvider(_ provider: CXProvider)

    /// Called when audio session is activated.
    @objc optional func activatedAudioSession(_ provider: CXProvider, didActivate audioSession: AVAudioSession)

    /// Called when audio session is deactivated.
    @objc optional func deactivatedAudioSession(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession)
}
