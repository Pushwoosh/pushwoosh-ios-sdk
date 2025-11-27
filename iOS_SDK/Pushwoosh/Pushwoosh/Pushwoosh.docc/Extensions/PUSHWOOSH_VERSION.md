# ``PUSHWOOSH_VERSION``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

The current version of the Pushwoosh SDK.

## Overview

This constant contains the version string of the Pushwoosh SDK currently in use. The version follows semantic versioning format (e.g., "7.0.6").

Use this for debugging, logging, or displaying SDK version information in your app.

## Example

Log SDK version for debugging or analytics:

```swift
func logAppEnvironment() {
    let sdkVersion = PUSHWOOSH_VERSION
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

    analytics.log("app_launch", properties: [
        "pushwoosh_sdk_version": sdkVersion,
        "app_version": appVersion,
        "platform": "iOS"
    ])
}
```

Display version in settings screen:

```swift
func buildAboutSection() -> [SettingsRow] {
    return [
        SettingsRow(title: "App Version", value: appVersion),
        SettingsRow(title: "Push SDK", value: PUSHWOOSH_VERSION)
    ]
}
```

