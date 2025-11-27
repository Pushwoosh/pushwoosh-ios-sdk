# ``Pushwoosh/setReverseProxy(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Changes default base URL to a reverse proxy URL.

## Overview

Route all Pushwoosh API requests through a custom reverse proxy server. Use this for:
- Enterprise security requirements
- Network traffic auditing
- Regional compliance
- Custom domain requirements

## Proxy Requirements

Your reverse proxy must:
- Forward requests to Pushwoosh API endpoints
- Preserve request headers and body
- Return responses unchanged
- Support HTTPS

## Example

Configure reverse proxy at app startup:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    if let proxyURL = Configuration.pushwooshProxyURL {
        Pushwoosh.configure.setReverseProxy(proxyURL)
    }

    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Set proxy based on environment:

```swift
func configurePushwoosh() {
    #if ENTERPRISE
    Pushwoosh.configure.setReverseProxy("https://pushwoosh-proxy.company.com")
    #endif

    Pushwoosh.configure.registerForPushNotifications()
}
```

## See Also

- ``Pushwoosh/disableReverseProxy()``
