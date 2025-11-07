# ``Pushwoosh/sendPushToStartLiveActivity(token:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sends push-to-start live activity token to the server.

## Discussion

**Deprecated since 6.8.0**: Use `Pushwoosh.LiveActivities.sendPushToStartLiveActivity(token:)` instead.

Call this method when you want to initiate a live activity via push notification. The token is obtained from the Activity's push-to-start token updates.

## Parameters

- token: The push-to-start live activity token
