# ``PWConfiguration``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Protocol defining SDK configuration methods.

## Discussion

The `PWConfiguration` protocol defines all methods available for configuring the Pushwoosh SDK. This protocol is implemented by the `PushwooshConfig` class, which can be accessed through `Pushwoosh.configure`.

The protocol provides methods for:
- Setting application code and API tokens
- Registering for push notifications
- Managing user identification
- Configuring SDK behavior

