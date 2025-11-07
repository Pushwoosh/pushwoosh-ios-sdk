# ``Pushwoosh/initialize(withAppCode:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Initializes the Pushwoosh SDK with your application code.

## Discussion

Use this method to manually initialize the SDK with your Pushwoosh Application Code. Alternatively, you can configure the Application Code in Info.plist with key `Pushwoosh_APPID` to enable automatic initialization.

After initialization, access the SDK through the shared instance to perform operations like registering for push notifications, setting tags, and managing user data.

## Parameters

- appCode: Your Pushwoosh Application Code from the Pushwoosh Control Panel
