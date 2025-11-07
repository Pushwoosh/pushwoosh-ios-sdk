# ``Pushwoosh/TVoS``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to tvOS-specific functionality.

## Discussion

Use this property to access tvOS-specific APIs for Apple TV applications. This interface provides methods tailored for the tvOS platform, including handling push notifications on Apple TV.

This property is only available when building for tvOS targets.

Access tvOS methods through this property:

```swift
Pushwoosh.TVoS.handleTVOSNotification()
```

