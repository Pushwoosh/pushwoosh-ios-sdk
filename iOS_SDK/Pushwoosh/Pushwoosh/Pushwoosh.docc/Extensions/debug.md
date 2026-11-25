# ``Pushwoosh/debug-type.property``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to debugging and logging functionality.

## Overview

Use this property to control SDK logging for development and troubleshooting. Available log levels:

- `.PW_LL_NONE` - No logging
- `.PW_LL_ERROR` - Errors only
- `.PW_LL_WARN` - Warnings and errors
- `.PW_LL_INFO` - Info, warnings, and errors
- `.PW_LL_DEBUG` - Debug messages and above
- `.PW_LL_VERBOSE` - All messages

## Example

Enable verbose logging during development:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    #if DEBUG
    Pushwoosh.debug.setLogLevel(.PW_LL_VERBOSE)
    #else
    Pushwoosh.debug.setLogLevel(.PW_LL_ERROR)
    #endif

    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Enable logging for troubleshooting:

```swift
func enableDiagnosticMode() {
    Pushwoosh.debug.setLogLevel(.PW_LL_VERBOSE)

    DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
        Pushwoosh.debug.setLogLevel(.PW_LL_ERROR)
    }
}
```

## See Also

- ``Pushwoosh/version()``
