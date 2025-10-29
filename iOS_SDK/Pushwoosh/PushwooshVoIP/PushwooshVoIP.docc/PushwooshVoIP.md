# ``PushwooshVoIP``

VoIP push notifications with native call UI for iOS applications.

## Overview

PushwooshVoIP integrates Apple's PushKit and CallKit frameworks to deliver VoIP push notifications and display native system call interface. VoIP pushes bypass standard notification delivery and wake your app directly, ensuring users never miss incoming calls.

The module handles PushKit token registration, CallKit provider configuration, and call lifecycle management automatically.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Examples>

### Core Classes

- ``PushwooshVoIPImplementation``

  Orchestrates VoIP push notifications and CallKit integration.

- ``PWVoIPMessage``

  An encapsulation of VoIP push notification payload data.

### Protocols

- ``PWVoIPCallDelegate``

  Delegate protocol for receiving VoIP call events.

### Configuration

- ``PushwooshVoIPImplementation/initializeVoIP(_:ringtoneSound:handleTypes:)``

  Initializes the VoIP module with CallKit configuration.

- ``PushwooshVoIPImplementation/setPushwooshVoIPAppId(_:)``

  Sets the Pushwoosh VoIP Application Code.

- ``PushwooshVoIPImplementation/delegate``

  The delegate that receives VoIP call events.

### Token Management

- ``PushwooshVoIPImplementation/setVoIPToken(_:)``

  Sets the VoIP push token manually.

### Handle Types

- ``PWVoIPHandleType``

  Display format for caller information in CallKit UI.

- ``PWVoIPHandleType/generic``

  Generic identifier like username or custom ID.

- ``PWVoIPHandleType/phoneNumber``

  Phone number with automatic formatting.

- ``PWVoIPHandleType/email``

  Email address format.

### Message Properties

- ``PWVoIPMessage/uuid``

  The unique identifier for the call.

- ``PWVoIPMessage/callerName``

  The caller's display name or identifier.

- ``PWVoIPMessage/handleType``

  The display format for caller information.

- ``PWVoIPMessage/hasVideo``

  A Boolean value that indicates whether the call supports video.

- ``PWVoIPMessage/supportsHolding``

  A Boolean value that indicates whether the call supports hold functionality.

- ``PWVoIPMessage/supportsDTMF``

  A Boolean value that indicates whether the call supports DTMF tones.

- ``PWVoIPMessage/rawPayload``

  The raw push notification payload.
