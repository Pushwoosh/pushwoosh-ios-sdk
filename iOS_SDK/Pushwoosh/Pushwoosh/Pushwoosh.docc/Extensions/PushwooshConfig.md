# ``PushwooshConfig``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Configuration interface for the Pushwoosh SDK.

## Discussion

The `PushwooshConfig` class provides static methods for configuring the Pushwoosh SDK. Access these methods through the `Pushwoosh.configure` property to set up your application code, API tokens, and other SDK settings.

This class implements the `PWConfiguration` protocol, providing all configuration methods needed to initialize and customize the SDK behavior.

Access configuration methods through:

```swift
Pushwoosh.configure.setAppCode("YOUR-APP-CODE")
Pushwoosh.configure.registerForPushNotifications()
```

