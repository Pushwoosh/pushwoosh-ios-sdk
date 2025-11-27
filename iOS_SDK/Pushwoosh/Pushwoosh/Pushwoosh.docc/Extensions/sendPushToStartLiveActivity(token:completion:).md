# ``Pushwoosh/sendPushToStartLiveActivity(token:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sends push-to-start live activity token to the server with a completion handler.

## Overview

> Deprecated: Use ``Pushwoosh/LiveActivities`` API instead.

Similar to `sendPushToStartLiveActivityToken:` but provides a callback when the operation completes.

## Example

Use the new LiveActivities API:

```swift
@available(iOS 17.2, *)
func setupPushToStartLiveActivity() {
    Task {
        for await token in Activity<DeliveryAttributes>.pushToStartTokenUpdates {
            let tokenString = token.map { String(format: "%02x", $0) }.joined()

            Pushwoosh.LiveActivities.sendPushToStartLiveActivity(token: tokenString) { error in
                if let error = error {
                    self.logger.error("Failed to send push-to-start token: \(error)")
                } else {
                    self.logger.info("Push-to-start token registered")
                }
            }
        }
    }
}
```

## See Also

- ``Pushwoosh/LiveActivities``
