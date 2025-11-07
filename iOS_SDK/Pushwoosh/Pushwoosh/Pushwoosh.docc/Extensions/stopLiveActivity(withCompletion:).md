# ``Pushwoosh/stopLiveActivity(withCompletion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Stops the current live activity with a completion handler.

## Discussion

**Deprecated since 6.8.0**: Use `Pushwoosh.LiveActivities.stopLiveActivity(completion:)` instead.

Similar to `stopLiveActivity()` but provides a callback when the operation completes.

## Parameters

- completion: Block called when the operation completes. Receives nil on success or an NSError on failure.
