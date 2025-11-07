# ``Pushwoosh/stopLiveActivity(with:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Stops a specific live activity by ID with a completion handler.

## Discussion

**Deprecated since 6.8.0**: Use `Pushwoosh.LiveActivities.stopLiveActivity(activityId:completion:)` instead.

Similar to `stopLiveActivityWith:` but provides a callback when the operation completes.

## Parameters

- activityId: The ID of the live activity to stop
- completion: Block called when the operation completes. Receives nil on success or an NSError on failure.
