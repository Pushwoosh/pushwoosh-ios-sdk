# ``Pushwoosh/showPushnotificationAlert``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Controls whether push notification alerts are shown when the app is running in the foreground.

## Discussion

When set to `true` (default), push notifications received while the app is in the foreground will display an alert to the user. When set to `false`, notifications are delivered silently to your delegate methods without showing an alert.

Set this property to `false` if you want to handle foreground notifications with custom UI instead of the system alert.

Default value is `true`.
