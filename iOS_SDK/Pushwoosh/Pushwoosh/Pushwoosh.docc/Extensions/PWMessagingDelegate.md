# ``PWMessagingDelegate``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Delegate protocol for handling push notification events.

## Discussion

The `PWMessagingDelegate` protocol defines methods that notify your app about push notification lifecycle events. Implement these methods to respond to notifications being received and opened by users.

## Overview

This protocol provides two key notification events:
- When a push notification arrives (received)
- When a user taps on a push notification (opened)

Both methods are called with a `PWMessage` object containing the notification payload and metadata.

Set your delegate on the shared Pushwoosh instance:

```swift
Pushwoosh.sharedInstance().delegate = self
```

Both methods are optional. Implement only the events you need to handle.

## Topics

### Handling Notifications

- ``pushwoosh:onMessageReceived:``
- ``pushwoosh:onMessageOpened:``

