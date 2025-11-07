# ``Pushwoosh/getRemoteNotificationStatus()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Returns a dictionary with enabled remote notification types.

## Discussion

Retrieves the current push notification permission status and enabled notification types. The dictionary includes information about whether alerts, badges, sounds, and CarPlay are enabled.

Example enabled push notification status:
```
{
   enabled = 1;
   pushAlert = 1;
   pushBadge = 1;
   pushSound = 1;
   type = 7;
}
```

Example disabled push notification status:
```
{
   enabled = 1;
   pushAlert = 0;
   pushBadge = 0;
   pushSound = 0;
   type = 0;
}
```

The "type" field corresponds to UIUserNotificationType values.

The "enabled" field indicates that the device can receive push notifications but may not display alerts (e.g., silent push).

## Returns

Dictionary containing notification status information, or nil if unavailable
