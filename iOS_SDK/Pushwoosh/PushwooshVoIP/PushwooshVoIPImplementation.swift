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

@available(iOS 14.0, *)
@objc(PushwooshVoIPImplementation)
public class PushwooshVoIPImplementation: NSObject, PWVoIP, PKPushRegistryDelegate, CXProviderDelegate {
    
    @objc(shared)
    public static let shared = PushwooshVoIPImplementation()
    
    @objc
    public static weak var delegate: AnyObject? {
        get { shared._delegate }
        set { shared._delegate = newValue as? (NSObjectProtocol & PWVoIPCallDelegate) }
    }
    
    private weak var _delegate: PWVoIPCallDelegate?
    
    var voipRegistry: PKPushRegistry!
    var callKitProvider: CXProvider!
    var callController: CXCallController!
    
    var voipPushMessage: PWVoIPMessage?
    var pushMessageDict: [String: PWVoIPMessage] = [:]

    @objc
    public static func voip() -> AnyClass {
        return PushwooshVoIPImplementation.self
    }
    
    // MARK: - Initialization (VoIP, CallKit)
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
        
        shared.callKitProvider = CXProvider(configuration: config)
        shared.callKitProvider.setDelegate(shared, queue: nil)
        
        shared.callController = CXCallController()
        
        shared.voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        shared.voipRegistry.delegate = shared
        shared.voipRegistry.desiredPushTypes = [.voIP]
        
        PushwooshVoIPImplementation.delegate?.returnedCallController(shared.callController)
        PushwooshVoIPImplementation.delegate?.returnedProvider(shared.callKitProvider)
    }
    
    @objc
    public static func setVoIPToken(_ token: Data) {
        shared.handleVoIPToken(token)
    }
    
    @objc
    public static func setPushwooshVoIPAppId(_ voipAppId: String) {
        shared.setPushwooshVoIPAppId(voipAppId)
    }
    
    // MARK: - PushKit Delegate
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let newToken = hexString(from: pushCredentials.token)
        let settings = PWSettings.settingsInstance()

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
        voipPushMessage = nil
        
        let voipMessage = PWVoIPMessage(rawPayload: payload.dictionaryPayload)
        
        let uuid = UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: voipMessage.handleType.toCXHandleType, value: voipMessage.callerName)
        update.hasVideo = voipMessage.hasVideo
        update.supportsHolding = voipMessage.supportsHolding
        update.supportsDTMF = voipMessage.supportsDTMF
        
        voipPushMessage = voipMessage
        voipPushMessage?.uuid = uuid.uuidString
        
        pushMessageDict[uuid.uuidString] = voipPushMessage
                
        if let voipMessage = voipPushMessage {
            PushwooshVoIPImplementation.delegate?.voipDidReceiveIncomingCall(payload: voipMessage)
        }
        
        callKitProvider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let delegate = PushwooshVoIPImplementation.delegate {
                if let error = error {
                    if delegate.responds(to: #selector(PWVoIPCallDelegate.voipDidFailToReportIncomingCall(error:))) {
                        delegate.voipDidFailToReportIncomingCall?(error: error)
                    }
                } else {
                    if delegate.responds(to: #selector(PWVoIPCallDelegate.voipDidReportIncomingCallSuccessfully(voipMessage:))) {
                        delegate.voipDidReportIncomingCallSuccessfully?(voipMessage: voipMessage)
                    }
                }
            }
            
            completion()
        }
    }
    
    // MARK: - CallKit Delegate
    // MARK: -
    // MARK: - Start Call Outcomming
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        if let delegate = PushwooshVoIPImplementation.delegate {
            if delegate.responds(to: #selector(PWVoIPCallDelegate.startCall(_:perform:))) {
                delegate.startCall?(provider, perform: action)
            }
        }
    }
    
    // MARK: - End Call
    // MARK: -
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let uuidString = action.callUUID.uuidString

        if let voipMessage = pushMessageDict[uuidString] {
            if let delegate = PushwooshVoIPImplementation.delegate,
               delegate.responds(to: #selector(PWVoIPCallDelegate.endCall(_:perform:voipMessage:))) {
                delegate.endCall?(provider, perform: action, voipMessage: voipMessage)
            }

            pushMessageDict.removeValue(forKey: uuidString)
        } else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, 
                                      className: self,
                                      message: "No VoIP message found for UUID: \(uuidString)")
        }
    }
    
    // MARK: - Answer Call
    // MARK: -
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let uuidString = action.callUUID.uuidString

        if let voipMessage = pushMessageDict[uuidString] {
            if let delegate = PushwooshVoIPImplementation.delegate,
               delegate.responds(to: #selector(PWVoIPCallDelegate.answerCall(_:perform:voipMessage:))) {
                delegate.answerCall?(provider, perform: action, voipMessage: voipMessage)
            }
        } else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, 
                                      className: self,
                                      message: "No VoIP message found for UUID: \(uuidString)")
        }
    }
    
    // MARK: - Muted Call
    // MARK: -
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        if let delegate = PushwooshVoIPImplementation.delegate {
            if delegate.responds(to: #selector(PWVoIPCallDelegate.mutedCall(_:perform:))) {
                delegate.mutedCall?(provider, perform: action)
            }
        }
    }
    
    // MARK: - Held Call
    // MARK: -
    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        if let delegate = PushwooshVoIPImplementation.delegate {
            if delegate.responds(to: #selector(PWVoIPCallDelegate.heldCall(_:perform:))) {
                delegate.heldCall?(provider, perform: action)
            }
        }
    }
    
    // MARK: - DTMF Tone
    // MARK: -
    public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        if let delegate = PushwooshVoIPImplementation.delegate {
            if delegate.responds(to: #selector(PWVoIPCallDelegate.playDTMF(_:perform:))) {
                delegate.playDTMF?(provider, perform: action)
            }
        }
    }
    
    // MARK: - Activate Audio Session
    // MARK: -
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        PushwooshVoIPImplementation.delegate?.activatedAudioSession(provider, didActivate: audioSession)
    }
    
    // MARK: - Deactivate Audio Session
    // MARK: -
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        PushwooshVoIPImplementation.delegate?.deactivatedAudioSession(provider, didDeactivate: audioSession)
    }
        
    public func providerDidReset(_ provider: CXProvider) {
        PushwooshVoIPImplementation.delegate?.pwProviderDidReset(provider)
    }
    
    public func providerDidBegin(_ provider: CXProvider) {
        PushwooshVoIPImplementation.delegate?.pwProviderDidBegin(provider)
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
    }
    
    private func handleVoIPToken(_ token: Data) {
        let requestParameters = VoIPRequestParameters(token: hexString(from: token))
        let request = PWSetVoIPTokenRequest(parameters: requestParameters)
        VoipNetworkManager.shared.sendInnerRequest(request: request) { error in
            self.handleVoIPTokenResult(error: error)
        }
    }
    
    private func setPushwooshVoIPAppId(_ voipAppId: String) {
        PWSettings.settingsInstance().voipAppCode = voipAppId
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
            PWSettings.settingsInstance().pushToken = nil
            PushwooshLog.pushwooshLog(.PW_LL_INFO, 
                                      className: self,
                                      message: "VoIP device successfully unregistered.")
        }
    }
    
    private func hexString(from deviceToken: Data) -> String {
        return deviceToken.map { String(format: "%02hhx", $0) }.joined()
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
