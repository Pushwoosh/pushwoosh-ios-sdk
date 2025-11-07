# ``Pushwoosh/LiveActivities``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to Live Activities functionality.

## Discussion

Use this property to access Live Activities APIs for managing iOS Live Activities with Pushwoosh. Live Activities display real-time information on the Lock Screen and Dynamic Island.

Access Live Activities methods through this property:

```swift
Pushwoosh.LiveActivities.startLiveActivity(token: token, activityId: activityId)
Pushwoosh.LiveActivities.stopLiveActivity()
```

