//
//  PWVoIP.swift
//  PushwooshBridge
//
//  Created by André on 6.5.25..
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import PushwooshCore

@objc
public protocol PWVoIP {
    /**
     Initializes VoIP configuration with the specified parameters.

     Call this method during app initialization before starting any CallKit-related operations.

     - Parameters:
       - supportVideo: A Boolean value indicating whether video calls are supported.
       - ringtoneSound: The name of the custom ringtone sound file to be used for incoming calls.
       - handleTypes: The type of call handle to support:
         (Pass one of the following values)
         
         - 1 – Generic
         - 2 – Phone number
         - 3 – Email address
     */
    @objc
    static func initializeVoIP(_ supportVideo: Bool,
                               ringtoneSound: String,
                               handleTypes: Int)
    
    /**
     Sets the VoIP push token for Pushwoosh.

     This method should be called once you receive the VoIP push token from the system.
     It registers the device with Pushwoosh to enable receiving VoIP push notifications.

     - Parameter token: The VoIP push token received from `PKPushRegistry`.

     - Important: Make sure to call this method from within the `pushRegistry(_:didUpdate:for:)` delegate method.

     - Usage:
     ```swift
     func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
         Pushwoosh.VoIP.setVoIPToken(pushCredentials.token)
     }
     */
    @objc
    static func setVoIPToken(_ token: Data)
    
    /**
     Configures the Pushwoosh VoIP App ID.

     - Parameter voipAppId: A Pushwoosh App ID (format: XXXXX-XXXXX) configured for VoIP push notifications.
     */
    @objc
    static func setPushwooshVoIPAppId(_ voipAppId: String)

    /**
     Sets the timeout duration for incoming VoIP calls.

     When an incoming call is not answered within this timeout period, it will be automatically
     ended and reported to the system as an unanswered (missed) call.

     - Parameter timeout: The timeout duration in seconds. Default value is 30.0 seconds.
     - Note: This method should be called before receiving any VoIP calls, typically during app initialization.
     */
    @objc
    static func setIncomingCallTimeout(_ timeout: TimeInterval)

    /** 
    A delegate object that conforms to the `PWVoIPCallDelegate` protocol.
    
    Use this property to set an object that handles VoIP call events such as answering,
    ending, muting, or playing DTMF tones. The delegate should conform to the
    `PWVoIPCallDelegate` protocol and must be assigned before handling any call actions.

    - Note: This is an optional static property. Set to `nil` to remove the delegate.

    - Usage (Swift):
    ```swift
    Pushwoosh.VoIP.delegate = self
    ```
    Ensure that `self` conforms to `PWVoIPCallDelegate`.

    - Usage (Objective-C):
    ```objc
    [[Pushwoosh VoIP] setDelegate:self];
    ```
    Make sure `self` conforms to `<PWVoIPCallDelegate>`.
     
    Call `.delegate = self` before `initializeVoip()`
    */
    @objc
    optional static
    var delegate: AnyObject? { get set }
}
