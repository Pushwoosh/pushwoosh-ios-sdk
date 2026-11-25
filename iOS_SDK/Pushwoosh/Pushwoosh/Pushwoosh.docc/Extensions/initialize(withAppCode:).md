# ``Pushwoosh/initialize(withAppCode:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Initializes the Pushwoosh SDK with your application code.

## Overview

Deprecated since 7.3.0. Set the Application Code in `Info.plist` or call `Pushwoosh.configure.setAppCode(_:)` instead. Use the runtime setter when you need to:
- Set the app code dynamically at runtime
- Support multiple Pushwoosh applications
- Start the SDK after user consent

## Info.plist Configuration

For most apps, configure in Info.plist:

```xml
<key>Pushwoosh_APPID</key>
<string>XXXXX-XXXXX</string>
```

## Example

Set the app code at runtime:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    let appCode = Configuration.pushwooshAppCode
    Pushwoosh.configure.setAppCode(appCode)

    Pushwoosh.configure.delegate = self
    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Set the app code after user consent:

```swift
func handlePrivacyConsentAccepted() {
    Pushwoosh.configure.setAppCode("XXXXX-XXXXX")
    Pushwoosh.configure.registerForPushNotifications()
}
```

Use one app code per build configuration:

```swift
func setupPushwoosh() {
    #if DEBUG
    Pushwoosh.configure.setAppCode("DEV-APPCODE")
    #else
    Pushwoosh.configure.setAppCode("PROD-APPCODE")
    #endif

    Pushwoosh.configure.registerForPushNotifications()
}
```

## See Also

- ``Pushwoosh/applicationCode``
- ``Pushwoosh/configure-type.property``
