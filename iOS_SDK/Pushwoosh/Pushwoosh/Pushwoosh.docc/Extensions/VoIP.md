# ``Pushwoosh/VoIP``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to VoIP push notification functionality.

## Discussion

Use this property to access VoIP (Voice over IP) push notification APIs. VoIP pushes allow your app to receive high-priority notifications for incoming calls and similar real-time communications.

VoIP pushes wake your app in the background and provide more time to process the notification compared to standard push notifications.

Access VoIP methods through this property:

```swift
Pushwoosh.VoIP.handleVoIPPushRegistration(deviceToken)
```

