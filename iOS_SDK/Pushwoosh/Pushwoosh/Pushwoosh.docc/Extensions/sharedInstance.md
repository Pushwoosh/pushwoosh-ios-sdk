# ``Pushwoosh/sharedInstance()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Returns the shared Pushwoosh SDK instance.

## Overview

Returns the singleton Pushwoosh instance. This is an alternative way to access SDK functionality.

## Recommended Usage

For cleaner code, prefer using ``configure`` which provides the same functionality:

```swift
// Recommended
Pushwoosh.configure.registerForPushNotifications()
Pushwoosh.configure.setTags(["key": "value"])

// Alternative (same functionality)
Pushwoosh.sharedInstance().registerForPushNotifications()
Pushwoosh.sharedInstance().setTags(["key": "value"])
```

## Prerequisites

The SDK must be initialized via Info.plist with key `Pushwoosh_APPID` before accessing.

## Example

Access SDK instance:

```swift
let pushwoosh = Pushwoosh.sharedInstance()
let hwid = pushwoosh.getHWID()
let token = pushwoosh.getPushToken()
```

## See Also

- ``Pushwoosh/configure``
