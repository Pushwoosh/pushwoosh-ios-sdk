# ``Pushwoosh/getHWID()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Returns the Pushwoosh Hardware ID (HWID) for this device.

## Overview

The HWID (Hardware ID) is a unique device identifier that Pushwoosh uses to identify devices across all API operations. This identifier is essential for:

- Tracking devices in Pushwoosh Control Panel
- Server-to-server API calls
- Matching user data across different systems
- Analytics and reporting

## Platform-Specific Implementation

| Platform | Underlying Identifier |
|----------|----------------------|
| iOS | `UIDevice.identifierForVendor` |
| macOS | `IOPlatformUUID` |

## Lifecycle

The HWID is generated on first SDK initialization and persists across:
- App launches
- App updates
- SDK updates

The HWID will change if:
- User reinstalls the app (iOS)
- User deletes all apps from the same vendor (iOS)

## Example

Sync device identifier with your backend for cross-system user matching:

```swift
func syncDeviceWithBackend(userId: String) {
    let hwid = Pushwoosh.configure.getHWID()

    let payload: [String: Any] = [
        "hwid": hwid,
        "userId": userId,
        "platform": "ios"
    ]

    apiClient.post("/devices/register", body: payload)
}
```

Use HWID for server-to-server push notification targeting:

```swift
func sendPushFromServer(to userId: String, message: String) {
    let hwid = Pushwoosh.configure.getHWID()

    serverAPI.sendPush(
        targetHWID: hwid,
        content: message
    )
}
```

## See Also

- ``Pushwoosh/getPushToken()``
- ``Pushwoosh/getUserId()``
- ``Pushwoosh/setUserId(_:)``
