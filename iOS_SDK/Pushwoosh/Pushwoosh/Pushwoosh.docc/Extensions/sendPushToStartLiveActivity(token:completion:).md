# ``Pushwoosh/sendPushToStartLiveActivity(token:completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sends push-to-start live activity token to the server with a completion handler.

## Discussion

**Deprecated since 6.8.0**: Use `Pushwoosh.LiveActivities.sendPushToStartLiveActivity(token:completion:)` instead.

Similar to `sendPushToStartLiveActivityToken:` but provides a callback when the operation completes.

## Parameters

- token: The push-to-start live activity token
- completion: Block called when the operation completes. Receives an NSError on failure or nil on success.
