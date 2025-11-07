# ``Pushwoosh/ForegroundPush``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to custom foreground push notification handling.

## Discussion

Use this property to access APIs for customizing how push notifications are displayed when your app is in the foreground. This allows you to control notification presentation and behavior when the user is actively using your app.

By default, notifications received while the app is in the foreground may not be displayed. Use this interface to customize this behavior.

Access foreground push methods through this property:

```swift
Pushwoosh.ForegroundPush.setCustomForegroundPresentationOptions()
```

