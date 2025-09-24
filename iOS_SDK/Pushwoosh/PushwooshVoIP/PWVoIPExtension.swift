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
}

/**
 PWVoIPCallDelegate provides callbacks for VoIP functionality including token registration and call management.
 
 */
@objc public protocol PWVoIPCallDelegate: NSObjectProtocol {
    // MARK: - VoIP Token Registration callbacks
    /// Called when VoIP token is successfully registered with Pushwoosh servers
    /// This callback is triggered after successful network registration of the device's VoIP push token
    @objc optional func voipDidRegisterTokenSuccessfully()
    
    /// Called when VoIP token registration fails
    /// This callback is triggered when there's an error during VoIP token registration with Pushwoosh servers
    /// - Parameter error: The error that occurred during token registration
    @objc optional func voipDidFailToRegisterToken(error: Error)
    
    // MARK: - Report new incoming call callbacks
    @objc func voipDidReceiveIncomingCall(payload: PWVoIPMessage)
    @objc optional func voipDidReportIncomingCallSuccessfully(voipMessage: PWVoIPMessage)
    @objc optional func voipDidFailToReportIncomingCall(error: Error)
    
    // MARK: - Call kit perform action
    // MARK: - `startCall` for outcome calls
    @objc optional func startCall(_ provider: CXProvider, perform action: CXStartCallAction)
    @objc optional func endCall(_ provider: CXProvider, perform action: CXEndCallAction, voipMessage: PWVoIPMessage?)
    @objc optional func answerCall(_ provider: CXProvider, perform action: CXAnswerCallAction, voipMessage: PWVoIPMessage?)
    @objc optional func mutedCall(_ provider: CXProvider, perform action: CXSetMutedCallAction)
    @objc optional func heldCall(_ provider: CXProvider, perform action: CXSetHeldCallAction)
    @objc optional func playDTMF(_ provider: CXProvider, perform action: CXPlayDTMFCallAction)
    
    // MARK: - Provider call kit
    @objc func pwProviderDidReset(_ provider: CXProvider)
    @objc func pwProviderDidBegin(_ provider: CXProvider)
    
    // MARK: - Objects
    @objc optional func returnedCallController(_ controller: CXCallController)
    @objc optional func returnedProvider(_ provider: CXProvider)
    
    // MARK: - Audio Session
    @objc optional func activatedAudioSession(_ provider: CXProvider, didActivate audioSession: AVAudioSession)
    @objc optional func deactivatedAudioSession(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession)
}
