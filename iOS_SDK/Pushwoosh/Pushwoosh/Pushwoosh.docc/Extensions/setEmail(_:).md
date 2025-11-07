# ``Pushwoosh/setEmail(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Associates an email address with the current device.

## Discussion

Register an email for the current user to enable email-based campaigns and user identification. The email address must be a valid, non-empty string.

The email is sent to Pushwoosh servers during the next network sync.

## Parameters

- email: The user's email address
