# ``Pushwoosh/registerSmsNumber(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers an SMS phone number for multi-channel messaging.

## Overview

Associates a phone number with the device to enable SMS campaigns alongside push notifications. This enables:
- SMS marketing campaigns
- Transactional SMS messages
- Multi-channel user engagement
- Fallback communication when push is unavailable

## Phone Number Format

Use international format with country code:
- `"+1234567890"` (with plus)
- `"1234567890"` (without plus)

## Example

Register phone number during onboarding:

```swift
func completePhoneVerification(phoneNumber: String) {
    Pushwoosh.configure.registerSmsNumber(phoneNumber)

    Pushwoosh.configure.setTags([
        "phone_verified": true,
        "phone_country": extractCountryCode(from: phoneNumber)
    ])
}
```

Update phone number in settings:

```swift
func updatePhoneNumber(_ phoneNumber: String) {
    let formattedNumber = formatInternational(phoneNumber)

    Pushwoosh.configure.registerSmsNumber(formattedNumber)

    showSuccess("Phone number updated")
}
```

## See Also

- ``Pushwoosh/registerWhatsappNumber(_:)``
- ``Pushwoosh/setEmail(_:)``
