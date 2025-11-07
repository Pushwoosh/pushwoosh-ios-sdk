# ``Pushwoosh/startLiveActivity(withToken:activityId:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sends live activity token to the server with a completion handler.

## Discussion

**Deprecated since 6.8.0**: Use `Pushwoosh.LiveActivities.startLiveActivity(token:activityId:completion:)` instead.

Similar to `startLiveActivityWithToken:activityId:` but provides a callback when the operation completes.

## Parameters

- token: The live activity token
- activityId: Activity ID for updating Live Activities by segments (optional)
- completion: Block called when the operation completes. Receives nil on success or an NSError on failure.
