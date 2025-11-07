# ``Pushwoosh/debug``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to debugging and logging functionality.

## Discussion

Use this property to access debugging APIs for troubleshooting and development. The debug interface allows you to control SDK logging levels and inspect SDK state.

Access debug methods through this property:

```swift
Pushwoosh.debug.setLogLevel(.verbose)
```

