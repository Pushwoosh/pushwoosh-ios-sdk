# ``Pushwoosh/stopLiveActivity()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Stops the current live activity.

## Overview

> Deprecated: Use ``Pushwoosh/LiveActivities`` API instead:
> ```swift
> Pushwoosh.LiveActivities.stopLiveActivity()
> ```

Notifies Pushwoosh servers that a Live Activity has ended.

## Example

End delivery tracking:

```swift
func completeDelivery() async {
    await activity.end(dismissalPolicy: .immediate)

    try? await Pushwoosh.LiveActivities.stopLiveActivity()
}
```

## See Also

- ``Pushwoosh/LiveActivities``
