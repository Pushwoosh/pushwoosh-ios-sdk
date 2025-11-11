//
//  PWVoIPMessage.swift
//  PushwooshVoIP
//
//  Created by André on 13.05.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshBridge

/// Display format for caller information in CallKit UI.
///
/// Specifies how the caller's identifier should be displayed in the system incoming call interface.
/// The handle type determines the formatting and presentation of the `callerName` field in CallKit.
@objc public enum PWVoIPHandleType: Int {
    /// Generic identifier like username or custom ID.
    ///
    /// Use this type for non-standard identifiers such as usernames, display names, or custom user IDs.
    /// CallKit will display the value exactly as provided without any special formatting.
    ///
    /// - Note: This is the default type if `handleType` is not specified in the VoIP push payload.
    case generic = 1

    /// Phone number with automatic formatting.
    ///
    /// Use this type when the caller identifier is a phone number. CallKit will automatically format
    /// the number according to the user's locale and system preferences.
    ///
    /// - Note: The phone number should be provided in E.164 format (e.g., +1234567890) for best results.
    case phoneNumber = 2

    /// Email address format.
    ///
    /// Use this type when the caller identifier is an email address. CallKit will display the email
    /// with appropriate email formatting in the incoming call UI.
    ///
    /// - Note: Ensure the email address is valid and properly formatted (e.g., user@example.com).
    case email = 3
}

/// An encapsulation of VoIP push notification payload data.
///
/// This class represents a VoIP push notification received from Pushwoosh servers. It contains all the information
/// needed to display an incoming call UI via CallKit, including caller details, call capabilities, and cancellation status.
@objc
public class PWVoIPMessage: NSObject {
    /// The unique identifier for the call.
    ///
    /// This UUID is used by CallKit to track the call throughout its lifecycle. The SDK automatically generates
    /// this identifier when a VoIP push is received, or uses the value from the payload if provided.
    ///
    /// - Note: This property is mutable to allow updating the UUID if needed during call setup.
    @objc public var uuid: String

    /// Server-provided call identifier for matching cancellation requests.
    ///
    /// This optional identifier is provided by your server to enable remote call cancellation. When a caller
    /// cancels their outgoing call, send a second VoIP push with the same `callId` and `cancelCall: true`.
    /// The SDK will automatically dismiss the CallKit UI on the recipient's device.
    ///
    /// - Note: If `nil`, call cancellation functionality is not available for this call.
    @objc public let callId: String?

    /// Indicates whether this push is a call cancellation request.
    ///
    /// When `true`, this VoIP push represents a cancellation of a previously sent incoming call.
    /// The SDK uses the `callId` field to match this cancellation with the active call and automatically
    /// dismisses the CallKit UI with `CXCallEndedReason.remoteEnded`.
    ///
    /// - Note: For regular incoming calls, this value is `false`. Only cancellation pushes should set this to `true`.
    @objc public let cancelCall: Bool

    /// The display format for caller information.
    ///
    /// Determines how the caller's identifier is displayed in CallKit UI. Choose the appropriate format
    /// based on your caller information type.
    ///
    /// Available values:
    /// - `.generic` - Generic identifier like username or custom ID (default if not specified)
    /// - `.phoneNumber` - Phone number with automatic system formatting
    /// - `.email` - Email address format
    ///
    /// - Note: The format affects how CallKit displays the caller information in the system UI.
    @objc public let handleType: PWVoIPHandleType

    /// The caller's display name or identifier.
    ///
    /// This string is displayed in the CallKit incoming call UI to identify who is calling.
    /// The format should match the `handleType` (e.g., phone number, email, or username).
    ///
    /// - Note: This value is shown prominently in the CallKit UI, so ensure it's user-friendly and recognizable.
    @objc public let callerName: String

    /// A Boolean value that indicates whether the call supports video.
    ///
    /// When `true`, the call is presented as a video call in CallKit UI with appropriate video call icons.
    /// When `false`, the call is presented as an audio-only call.
    ///
    /// - Note: This property is mutable to allow updating video capability during call setup if needed.
    @objc public var hasVideo: Bool

    /// A Boolean value that indicates whether the call supports hold functionality.
    ///
    /// When `true`, CallKit UI will display a hold button allowing the user to put the call on hold.
    /// Your app should implement the `heldCall` delegate method to handle hold state changes.
    ///
    /// - Note: If `false`, the hold button will not appear in CallKit UI.
    @objc public let supportsHolding: Bool

    /// A Boolean value that indicates whether the call supports DTMF tones.
    ///
    /// When `true`, CallKit UI will display a keypad allowing the user to send DTMF tones during the call.
    /// Your app should implement the `playDTMF` delegate method to handle DTMF tone generation.
    ///
    /// - Note: If `false`, the keypad will not be available in CallKit UI.
    @objc public let supportsDTMF: Bool

    /// The raw push notification payload.
    ///
    /// Contains the complete original payload received from the VoIP push notification, with `NSNull` values
    /// removed. Use this to access any custom fields you included in your VoIP push that are not part of
    /// the standard PWVoIPMessage properties.
    ///
    /// - Note: All standard properties (callerName, hasVideo, etc.) are parsed from this payload during initialization.
    @objc public let rawPayload: [AnyHashable: Any]

    /// Creates a VoIP message from push notification payload.
    ///
    /// Initializes a new VoIP message by parsing the raw push notification payload dictionary.
    /// The initializer extracts standard fields like `callerName`, `callId`, `cancelCall`, `video`, etc.,
    /// and stores the complete payload for custom field access.
    ///
    /// Payload field mapping:
    /// - `callId` → `callId` property (optional String)
    /// - `cancelCall` → `cancelCall` property (Bool, defaults to false)
    /// - `handleType` → `handleType` property (Int mapped to PWVoIPHandleType, defaults to .generic)
    /// - `uuid` → `uuid` property (String, defaults to empty string)
    /// - `callerName` → `callerName` property (String, defaults to empty string)
    /// - `video` → `hasVideo` property (Bool, defaults to false)
    /// - `supportsHolding` → `supportsHolding` property (Bool, defaults to false)
    /// - `supportsDTMF` → `supportsDTMF` property (Bool, defaults to false)
    ///
    /// - Parameter rawPayload: The dictionary containing VoIP push notification data. NSNull values are automatically removed.
    ///
    /// - Note: All fields are optional in the payload. Missing fields will use default values to ensure valid message state.
    public init(rawPayload: [AnyHashable: Any]) {
        self.rawPayload = rawPayload.compactMapValues { $0 is NSNull ? nil : $0 }

        self.callId = rawPayload["callId"] as? String
        self.cancelCall = rawPayload["cancelCall"] as? Bool ?? false

        if let handleTypeRaw = rawPayload["handleType"] as? Int,
           let handleType = PWVoIPHandleType(rawValue: handleTypeRaw) {
            self.handleType = handleType
        } else {
            self.handleType = .generic
        }

        self.uuid = rawPayload["uuid"] as? String ?? ""
        self.callerName = rawPayload["callerName"] as? String ?? ""
        self.hasVideo = rawPayload["video"] as? Bool ?? false
        self.supportsHolding = rawPayload["supportsHolding"] as? Bool ?? false
        self.supportsDTMF = rawPayload["supportsDTMF"] as? Bool ?? false
    }
}


