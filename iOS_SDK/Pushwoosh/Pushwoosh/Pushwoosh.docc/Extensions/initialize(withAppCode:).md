# ``Pushwoosh/initialize(withAppCode:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Initializes the Pushwoosh SDK with your application code.

## Overview

Manually initializes the SDK with your Pushwoosh Application Code. Use this when you need to:
- Set the app code dynamically at runtime
- Support multiple Pushwoosh applications
- Initialize SDK after user consent

## Alternative: Info.plist Configuration

For most apps, configure in Info.plist instead:

```xml
<key>Pushwoosh_APPID</key>
<string>XXXXX-XXXXX</string>
```

## Example

Initialize with dynamic app code:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    let appCode = Configuration.pushwooshAppCode
    Pushwoosh.initialize(withAppCode: appCode)

    Pushwoosh.configure.delegate = self
    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Initialize after user consent:

```swift
func handlePrivacyConsentAccepted() {
    Pushwoosh.initialize(withAppCode: "XXXXX-XXXXX")
    Pushwoosh.configure.registerForPushNotifications()
}
```

Support multiple environments:

```swift
func setupPushwoosh() {
    #if DEBUG
    Pushwoosh.initialize(withAppCode: "DEV-APPCODE")
    #else
    Pushwoosh.initialize(withAppCode: "PROD-APPCODE")
    #endif

    Pushwoosh.configure.registerForPushNotifications()
}
```

## See Also

- ``Pushwoosh/applicationCode``
- ``Pushwoosh/configure``
