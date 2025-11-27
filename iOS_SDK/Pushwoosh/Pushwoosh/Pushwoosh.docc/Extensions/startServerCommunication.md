# ``Pushwoosh/startServerCommunication()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Starts communication with Pushwoosh server.

## Overview

Enables network communication with Pushwoosh servers. Use this method to resume SDK operations after calling ``stopServerCommunication()``.

When communication is enabled, the SDK will:
- Send pending device registration
- Sync queued tags
- Report pending analytics events
- Resume all server interactions

## Default State

Server communication is **enabled by default**. You only need to call this method after explicitly stopping communication.

## Example

Resume communication after user accepts privacy policy:

```swift
func handlePrivacyPolicyAccepted() {
    userDefaults.set(true, forKey: "privacyAccepted")

    Pushwoosh.configure.startServerCommunication()
    Pushwoosh.configure.registerForPushNotifications()
}
```

Toggle communication based on user preference:

```swift
func updateDataSharingPreference(enabled: Bool) {
    if enabled {
        Pushwoosh.configure.startServerCommunication()
    } else {
        Pushwoosh.configure.stopServerCommunication()
    }

    userDefaults.set(enabled, forKey: "dataSharing")
}
```

## See Also

- ``Pushwoosh/stopServerCommunication()``
