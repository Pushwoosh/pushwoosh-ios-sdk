# ``Pushwoosh/startLiveActivity(withToken:activityId:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sends live activity token to the server.

## Discussion

**Deprecated since 6.8.0**: Use `Pushwoosh.LiveActivities.startLiveActivity(token:activityId:)` instead.

Call this method when you create a live activity. The token is obtained from the Activity's push token updates, and the activity ID enables updating Live Activities by segments.

## Parameters

- token: The live activity token
- activityId: Activity ID for updating Live Activities by segments (optional)
