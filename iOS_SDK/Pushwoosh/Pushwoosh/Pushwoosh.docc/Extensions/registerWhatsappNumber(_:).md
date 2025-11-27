# ``Pushwoosh/registerWhatsappNumber(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers a WhatsApp phone number for multi-channel messaging.

## Overview

Associates a WhatsApp number with the device to enable WhatsApp Business campaigns. This enables:
- WhatsApp marketing messages
- Rich media messages via WhatsApp
- Interactive message templates
- Multi-channel engagement strategy

## Phone Number Format

Use international format with country code:
- `"+1234567890"` (with plus)
- `"1234567890"` (without plus)

## Example

Register WhatsApp number after verification:

```swift
func handleWhatsAppVerified(phoneNumber: String) {
    Pushwoosh.configure.registerWhatsappNumber(phoneNumber)

    Pushwoosh.configure.setTags([
        "whatsapp_enabled": true,
        "preferred_channel": "whatsapp"
    ])
}
```

Offer WhatsApp opt-in:

```swift
func showWhatsAppOptIn() {
    let alert = UIAlertController(
        title: "Get Updates on WhatsApp",
        message: "Receive order updates and offers on WhatsApp",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Enable", style: .default) { _ in
        if let phone = self.userProfile.phoneNumber {
            Pushwoosh.configure.registerWhatsappNumber(phone)
        }
    })

    alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))

    present(alert, animated: true)
}
```

## See Also

- ``Pushwoosh/registerSmsNumber(_:)``
- ``Pushwoosh/setEmail(_:)``
