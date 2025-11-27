# ``Pushwoosh/version()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Returns the Pushwoosh SDK version.

## Overview

Retrieves the current version string of the Pushwoosh SDK. Useful for:
- Debugging and troubleshooting
- Support tickets
- Analytics and logging
- Version-specific feature checks

## Example

Include SDK version in support tickets:

```swift
func createSupportTicket(issue: String) -> SupportTicket {
    return SupportTicket(
        issue: issue,
        sdkVersion: Pushwoosh.version(),
        appVersion: Bundle.main.appVersion,
        hwid: Pushwoosh.configure.getHWID(),
        osVersion: UIDevice.current.systemVersion
    )
}
```

Log SDK version on app launch:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Analytics.log("app_launched", [
        "pushwoosh_version": Pushwoosh.version(),
        "app_version": Bundle.main.appVersion
    ])

    return true
}
```

## See Also

- ``Pushwoosh/getHWID()``
