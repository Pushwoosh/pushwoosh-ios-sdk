# ``Pushwoosh/launchNotification``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

The push notification payload that launched the app.

## Discussion

This property contains the push notification payload if the app was started in response to the user tapping a push notification. If the app was launched normally (not from a notification), this property is `nil`.

Use this property to handle deep linking or navigation when your app is launched from a cold start via a push notification. The dictionary contains the full notification payload including any custom data.

This is a read-only property.
