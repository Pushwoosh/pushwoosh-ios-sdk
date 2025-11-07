# ``Pushwoosh/additionalAuthorizationOptions``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Additional authorization options for push notifications.

## Discussion

Use this property to request additional notification authorization options beyond the default set. The SDK automatically requests `UNAuthorizationOptionBadge`, `UNAuthorizationOptionSound`, `UNAuthorizationOptionAlert`, and `UNAuthorizationOptionCarPlay`.

Set this property before calling `registerForPushNotifications()` to request additional options such as provisional authorization, critical alerts, or announcement notifications.

Available on iOS 12.0 and later.

