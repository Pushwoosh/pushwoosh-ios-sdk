//
//  PushwooshVoIPImplementation.swift
//  PushwooshVoIP
//
//  Created by André on 6.5.25..
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore
import PushwooshBridge
import PushKit
import CallKit
import AVFoundation

/// Orchestrates VoIP push notifications and CallKit integration for iOS applications.
@available(iOS 14.0, *)
@objc(PushwooshVoIPImplementation)
public class PushwooshVoIPImplementation: NSObject, PWVoIP, PKPushRegistryDelegate, CXProviderDelegate {

    /// Shared singleton instance.
    @objc(shared)
    public static let shared = PushwooshVoIPImplementation()

    /// The delegate that receives VoIP call events.
    @objc
    public static weak var delegate: AnyObject? {
        get { shared._delegate }
        set {
            if let delegate = newValue as? (NSObjectProtocol & PWVoIPCallDelegate) {
                shared._delegate = delegate
            } else if newValue != nil {
                PushwooshLog.pushwooshLog(.PW_LL_ERROR,
                                          className: self,
                                          message: "Invalid delegate type. Must conform to PWVoIPCallDelegate")
                shared._delegate = nil
            } else {
                shared._delegate = nil
            }
        }
    }

    private weak var _delegate: PWVoIPCallDelegate?

    private var voipRegistry: PKPushRegistry?
    private var callKitProvider: CXProvider?
    private var callController: CXCallController?

    private var voipPushMessage: PWVoIPMessage?
    private var pushMessageDict: [String: PWVoIPMessage] = [:]
    private var callIdToUUIDMap: [String: UUID] = [:]

    private var incomingCallTimeout: TimeInterval = 30.0
    private var callTimeoutWorkItems: [String: DispatchWorkItem] = [:]

    /// Serial queue for thread-safe access to shared state
    private let syncQueue = DispatchQueue(label: "com.pushwoosh.voip.sync", qos: .userInitiated)

    /// Returns the VoIP implementation class.
    @objc
    public static func voip() -> AnyClass {
        return PushwooshVoIPImplementation.self
    }

    // MARK: - Initialization (VoIP, CallKit)
    /// Initializes the VoIP module with CallKit configuration.
    @objc
    public static func initializeVoIP(_ supportVideo: Bool,
                                      ringtoneSound: String,
                                      handleTypes: Int) {
        let config = CXProviderConfiguration()
        config.supportsVideo = supportVideo
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.ringtoneSound = ringtoneSound
        config.supportedHandleTypes = handleTypes.toCXSetHandleType

        let provider = CXProvider(configuration: config)
        provider.setDelegate(shared, queue: nil)
        shared.callKitProvider = provider

        let controller = CXCallController()
        shared.callController = controller

        let registry = PKPushRegistry(queue: DispatchQueue.main)
        registry.delegate = shared
        registry.desiredPushTypes = [.voIP]
        shared.voipRegistry = registry

        PushwooshVoIPImplementation.delegate?.returnedCallController(controller)
        PushwooshVoIPImplementation.delegate?.returnedProvider(provider)
    }

    /// Sets the VoIP push token manually.
    @objc
    public static func setVoIPToken(_ token: Data) {
        shared.handleVoIPToken(token)
    }

    /// Sets the Pushwoosh VoIP Application Code.
    @objc
    public static func setPushwooshVoIPAppId(_ voipAppId: String) {
        shared.setPushwooshVoIPAppId(voipAppId)
    }

    @objc
    public static func setIncomingCallTimeout(_ timeout: TimeInterval) {
        shared.syncQueue.async {
            shared.incomingCallTimeout = timeout
        }
        PushwooshLog.pushwooshLog(.PW_LL_DEBUG,
                                  className: self,
                                  message: "Incoming call timeout set to \(timeout) seconds")
    }

    // MARK: - PushKit Delegate
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let newToken = hexString(from: pushCredentials.token)
        let settings = PWPreferences.preferencesInstance()

        guard newToken != settings.voipPushToken else {
            return
        }

        settings.voipPushToken = newToken
        handleVoIPToken(pushCredentials.token)
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        unregisterVoIPDeviceRequest()
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        let voipMessage = PWVoIPMessage(rawPayload: payload.dictionaryPayload)

        if voipMessage.cancelCall {
            handleCallCancellation(voipMessage: voipMessage)
            completion()
            return
        }

        let uuid = UUID()
        let uuidString = uuid.uuidString

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: voipMessage.handleType.toCXHandleType, value: voipMessage.callerName)
        update.hasVideo = voipMessage.hasVideo
        update.supportsHolding = voipMessage.supportsHolding
        update.supportsDTMF = voipMessage.supportsDTMF

        var voipWithUUID = voipMessage
        voipWithUUID.uuid = uuidString

        // Thread-safe write to shared state
        syncQueue.async {
            self.voipPushMessage = voipWithUUID
            self.pushMessageDict[uuidString] = voipWithUUID
        }

        PushwooshVoIPImplementation.delegate?.voipDidReceiveIncomingCall(payload: voipWithUUID)

        guard let provider = callKitProvider else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR,
                                      className: self,
                                      message: "CallKit provider not initialized. Call initializeVoIP() first.")
            completion()
            return
        }

        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            guard let self = self else {
                completion()
                return
            }

            if let error = error {
                PushwooshVoIPImplementation.delegate?.voipDidFailToReportIncomingCall?(error: error)
            } else {
                self.startTimeoutTimer(for: uuidString)

                if let callId = voipMessage.callId {
                    self.syncQueue.async {
                        self.callIdToUUIDMap[callId] = uuid

                        PushwooshLog.pushwooshLog(.PW_LL_INFO,
                                                  className: self,
                                                  message: "Stored callId mapping: \(callId) → \(uuid.uuidString)")
                    }
                }

                PushwooshVoIPImplementation.delegate?.voipDidReportIncomingCallSuccessfully?(voipMessage: voipWithUUID)
            }

            completion()
        }
    }
    
    // MARK: - CallKit Delegate

    // MARK: - Start Outgoing Call
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        PushwooshVoIPImplementation.delegate?.startCall?(provider, perform: action)
        action.fulfill()
    }
    
    // MARK: - End Call
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let uuidString = action.callUUID.uuidString

        cancelTimeoutTimer(for: uuidString)

        syncQueue.async {
            if let voipMessage = self.pushMessageDict[uuidString] {
                PushwooshVoIPImplementation.delegate?.endCall?(provider, perform: action, voipMessage: voipMessage)

                if let callId = voipMessage.callId {
                    self.callIdToUUIDMap.removeValue(forKey: callId)

                    PushwooshLog.pushwooshLog(.PW_LL_INFO,
                                              className: self,
                                              message: "Removed callId mapping on call end: \(callId)")
                }

                self.pushMessageDict.removeValue(forKey: uuidString)
                action.fulfill()
            } else {
                PushwooshLog.pushwooshLog(.PW_LL_ERROR,
                                          className: self,
                                          message: "No VoIP message found for UUID: \(uuidString)")
                action.fail()
            }
        }
    }
    
    // MARK: - Answer Call
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let uuidString = action.callUUID.uuidString

        cancelTimeoutTimer(for: uuidString)

        syncQueue.async {
            if let voipMessage = self.pushMessageDict[uuidString] {
                PushwooshVoIPImplementation.delegate?.answerCall?(provider, perform: action, voipMessage: voipMessage)

                if let callId = voipMessage.callId {
                    self.callIdToUUIDMap.removeValue(forKey: callId)

                    PushwooshLog.pushwooshLog(.PW_LL_INFO,
                                              className: self,
                                              message: "Removed callId mapping on call answer: \(callId)")
                }

                action.fulfill()
            } else {
                PushwooshLog.pushwooshLog(.PW_LL_ERROR,
                                          className: self,
                                          message: "No VoIP message found for UUID: \(uuidString)")
                action.fail()
            }
        }
    }
    
    // MARK: - Muted Call
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        PushwooshVoIPImplementation.delegate?.mutedCall?(provider, perform: action)
        action.fulfill()
    }

    // MARK: - Held Call
    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        PushwooshVoIPImplementation.delegate?.heldCall?(provider, perform: action)
        action.fulfill()
    }

    // MARK: - DTMF Tone
    public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        PushwooshVoIPImplementation.delegate?.playDTMF?(provider, perform: action)
        action.fulfill()
    }
    
    // MARK: - Activate Audio Session
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        PushwooshVoIPImplementation.delegate?.activatedAudioSession(provider, didActivate: audioSession)
    }

    // MARK: - Deactivate Audio Session
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        PushwooshVoIPImplementation.delegate?.deactivatedAudioSession(provider, didDeactivate: audioSession)
    }
        
    public func providerDidReset(_ provider: CXProvider) {
        PushwooshVoIPImplementation.delegate?.pwProviderDidReset(provider)
    }
    
    public func providerDidBegin(_ provider: CXProvider) {
        PushwooshVoIPImplementation.delegate?.pwProviderDidBegin(provider)
    }

    // MARK: - Call Cancellation

    private func handleCallCancellation(voipMessage: PWVoIPMessage) {
        guard let callId = voipMessage.callId else {
            let reason = "Received cancel request without callId. Cannot cancel call."
            PushwooshLog.pushwooshLog(.PW_LL_WARN,
                                      className: self,
                                      message: reason)

            if let delegate = PushwooshVoIPImplementation.delegate,
               delegate.responds(to: #selector(PWVoIPCallDelegate.voipDidFailToCancelCall(callId:reason:))) {
                delegate.voipDidFailToCancelCall?(callId: nil, reason: reason)
            }
            return
        }

        syncQueue.async {
            guard let uuid = self.callIdToUUIDMap[callId] else {
                let reason = "No active call found for callId: \(callId). Call may have already ended or been answered."
                PushwooshLog.pushwooshLog(.PW_LL_WARN,
                                          className: self,
                                          message: reason)

                if let delegate = PushwooshVoIPImplementation.delegate,
                   delegate.responds(to: #selector(PWVoIPCallDelegate.voipDidFailToCancelCall(callId:reason:))) {
                    delegate.voipDidFailToCancelCall?(callId: callId, reason: reason)
                }
                return
            }

            PushwooshLog.pushwooshLog(.PW_LL_INFO,
                                      className: self,
                                      message: "Cancelling call with callId: \(callId), UUID: \(uuid.uuidString)")

            let uuidString = uuid.uuidString
            let cancelledVoipMessage = self.pushMessageDict[uuidString]

            self.callKitProvider?.reportCall(with: uuid,
                                             endedAt: Date(),
                                             reason: .remoteEnded)

            self.pushMessageDict.removeValue(forKey: uuidString)
            self.callIdToUUIDMap.removeValue(forKey: callId)
            self.cancelTimeoutTimer(for: uuidString)

            if let voipMessage = cancelledVoipMessage,
               let delegate = PushwooshVoIPImplementation.delegate,
               delegate.responds(to: #selector(PWVoIPCallDelegate.voipDidCancelCall(voipMessage:))) {
                delegate.voipDidCancelCall?(voipMessage: voipMessage)
            }
        }
    }

    // MARK: - Private Helpers
    private func handleVoIPTokenResult(error: Error?) {
        let logLevel: PUSHWOOSH_LOG_LEVEL = error == nil ? .PW_LL_INFO : .PW_LL_ERROR
        let message = error == nil ?
            "Successfully sent voip token." :
            "Failed to send voip token. Error: \(error!.localizedDescription)"
        
        PushwooshLog.pushwooshLog(logLevel, 
                                  className: self,
                                  message: message)
        
        if let delegate = PushwooshVoIPImplementation.delegate {
            if let error = error {
                if delegate.responds(to: #selector(PWVoIPCallDelegate.voipDidFailToRegisterToken(error:))) {
                    delegate.voipDidFailToRegisterToken?(error: error)
                }
            } else {
                if delegate.responds(to: #selector(PWVoIPCallDelegate.voipDidRegisterTokenSuccessfully)) {
                    delegate.voipDidRegisterTokenSuccessfully?()
                }
            }
        }
    }
    
    private func handleVoIPToken(_ token: Data) {
        let requestParameters = VoIPRequestParameters(token: hexString(from: token))
        let request = PWSetVoIPTokenRequest(parameters: requestParameters)
        VoipNetworkManager.shared.sendInnerRequest(request: request) { error in
            self.handleVoIPTokenResult(error: error)
        }
    }
    
    private func setPushwooshVoIPAppId(_ voipAppId: String) {
        PWPreferences.preferencesInstance().voipAppCode = voipAppId
    }
    
    private func unregisterVoIPDeviceRequest() {
        let requestParameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: requestParameters)
        VoipNetworkManager.shared.sendInnerRequest(request: request) { error in
            self.handleVoIPDeviceUnregisterResult(error: error)
        }
    }
    
    private func handleVoIPDeviceUnregisterResult(error: Error?) {
        if let error = error {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, 
                                      className: self,
                                      message: "Failed device unregistered. Error: \(error.localizedDescription)")
        } else {
            PWPreferences.preferencesInstance().pushToken = nil
            PushwooshLog.pushwooshLog(.PW_LL_INFO, 
                                      className: self,
                                      message: "VoIP device successfully unregistered.")
        }
    }
    
    private func hexString(from deviceToken: Data) -> String {
        return deviceToken.map { String(format: "%02hhx", $0) }.joined()
    }

    private func startTimeoutTimer(for callUUID: String) {
        // Validate UUID before creating workItem to prevent memory leak
        guard UUID(uuidString: callUUID) != nil else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR,
                                      className: self,
                                      message: "Invalid UUID string: \(callUUID)")
            return
        }

        cancelTimeoutTimer(for: callUUID)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard let uuid = UUID(uuidString: callUUID) else { return }

            PushwooshLog.pushwooshLog(.PW_LL_INFO,
                                      className: self,
                                      message: "Call timeout reached for UUID: \(callUUID). Reporting as unanswered.")

            self.callKitProvider?.reportCall(with: uuid,
                                             endedAt: Date(),
                                             reason: .unanswered)

            // Thread-safe cleanup
            self.syncQueue.async {
                self.pushMessageDict.removeValue(forKey: callUUID)
                self.callTimeoutWorkItems.removeValue(forKey: callUUID)
            }
        }

        // Thread-safe write
        syncQueue.async {
            self.callTimeoutWorkItems[callUUID] = workItem
        }

        // Get timeout value thread-safely
        let timeout = syncQueue.sync { self.incomingCallTimeout }

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)

        PushwooshLog.pushwooshLog(.PW_LL_DEBUG,
                                  className: self,
                                  message: "Started \(timeout)s timeout timer for call UUID: \(callUUID)")
    }

    private func cancelTimeoutTimer(for callUUID: String) {
        syncQueue.async {
            if let workItem = self.callTimeoutWorkItems[callUUID] {
                workItem.cancel()
                self.callTimeoutWorkItems.removeValue(forKey: callUUID)

                PushwooshLog.pushwooshLog(.PW_LL_DEBUG,
                                          className: self,
                                          message: "Cancelled timeout timer for call UUID: \(callUUID)")
            }
        }
    }
}

extension Int {
    var toCXSetHandleType: Set<CXHandle.HandleType> {
        switch self {
        case 1:
            return [.generic]
        case 2:
            return [.phoneNumber]
        case 3:
            return [.emailAddress]
        default:
            return [.generic]
        }
    }
}

extension PWVoIPHandleType {
    var toCXHandleType: CXHandle.HandleType {
        switch self {
        case .generic:
            return .generic
        case .phoneNumber:
            return .phoneNumber
        case .email:
            return .emailAddress
        @unknown default:
            return .generic
        }
    }
}
