# ``PushwooshRegistrationHandler``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Completion handler called when push notification registration completes.

## Discussion

This closure is called when the device registration process finishes, either successfully or with an error.

The handler receives two parameters:
- **token**: The push token string if registration succeeded, or `nil` if it failed
- **error**: An error object if registration failed, or `nil` if it succeeded

Use this handler to respond to registration results, such as storing the token, updating UI, or handling errors.

