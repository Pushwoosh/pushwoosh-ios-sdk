# ``Pushwoosh/debug``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to debugging and logging functionality.

## Overview

Use this property to control SDK logging for development and troubleshooting. Available log levels:

- `.none` - No logging
- `.error` - Errors only
- `.warning` - Warnings and errors
- `.info` - Info, warnings, and errors
- `.debug` - Debug messages and above
- `.verbose` - All messages

## Example

Enable verbose logging during development:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    #if DEBUG
    Pushwoosh.debug.setLogLevel(.verbose)
    #else
    Pushwoosh.debug.setLogLevel(.error)
    #endif

    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Enable logging for troubleshooting:

```swift
func enableDiagnosticMode() {
    Pushwoosh.debug.setLogLevel(.verbose)

    DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
        Pushwoosh.debug.setLogLevel(.error)
    }
}
```

## See Also

- ``Pushwoosh/version()``
