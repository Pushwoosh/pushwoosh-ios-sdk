# ``Pushwoosh/setEmail(_:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Associates an email address with the current device with a completion handler.

## Discussion

Register an email for the current user to enable email-based campaigns and user identification. The email address must be a valid, non-empty string.

## Parameters

- email: The user's email address
- completion: Block called when the operation completes. Receives nil on success or an NSError on failure.
