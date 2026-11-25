# ``Pushwoosh/setEmail(_:)-7syp6``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Associates an email address with the current device.

## Overview

Register a user's email to enable:
- Email channel campaigns in Pushwoosh
- Cross-channel messaging (push + email)
- User identification by email address
- Email-based segmentation

## Validation

The email must be:
- Non-empty string
- Valid email format

Invalid emails will be rejected by the server.

## Example

Set email during user registration:

```swift
func completeRegistration(email: String, password: String) async throws {
    let user = try await authService.register(email: email, password: password)

    try await Pushwoosh.configure.setUserId(user.id)
    try await Pushwoosh.configure.setEmail(email)

    try await Pushwoosh.configure.setTags([
        "registration_date": Date(),
        "registration_source": "ios_app"
    ])
}
```

Update email when user changes it in settings:

```swift
func updateEmail(newEmail: String) {
    Pushwoosh.configure.setEmail(newEmail)

    Pushwoosh.configure.setTags([
        "email_updated": Date()
    ])
}
```

## See Also

- ``Pushwoosh/setEmail(_:)-2x3e8``
- ``Pushwoosh/setEmails(_:)-8qzt8``
- ``Pushwoosh/setUserId(_:)-59ept``
- ``Pushwoosh/setTags(_:)-6njl3``
