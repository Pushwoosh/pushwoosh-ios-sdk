# ``Pushwoosh/applicationCode``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

The Pushwoosh Application ID.

## Overview

Your unique Pushwoosh Application Code that identifies your app. This value is typically configured in Info.plist with key `Pushwoosh_APPID`.

## Configuration

Set in Info.plist:

```xml
<key>Pushwoosh_APPID</key>
<string>XXXXX-XXXXX</string>
```

Or programmatically before registration:

```swift
Pushwoosh.configure.setAppCode("XXXXX-XXXXX")
```

## Example

Include app code in diagnostics:

```swift
func createDiagnosticReport() -> DiagnosticReport {
    return DiagnosticReport(
        appCode: Pushwoosh.configure.applicationCode ?? "Not configured",
        hwid: Pushwoosh.configure.getHWID(),
        pushToken: Pushwoosh.configure.getPushToken(),
        sdkVersion: Pushwoosh.version()
    )
}
```

Verify configuration:

```swift
func verifyPushwooshSetup() -> Bool {
    guard let appCode = Pushwoosh.configure.applicationCode,
          !appCode.isEmpty else {
        print("Pushwoosh App Code not configured")
        return false
    }
    return true
}
```

## See Also

- ``Pushwoosh/getHWID()``
- ``Pushwoosh/version()``
