# ``Pushwoosh/handleOpenURL(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Processes deep link URLs.

## Overview

Handles special Pushwoosh URLs, primarily used for:
- Registering test devices via QR code
- Development and debugging workflows
- Pushwoosh Control Panel device linking

## Return Value

- `true` - URL was handled by Pushwoosh
- `false` - URL is not a Pushwoosh URL, handle it yourself

## Example

Handle URLs in AppDelegate:

```swift
func application(_ app: UIApplication,
                open url: URL,
                options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

    if Pushwoosh.configure.handleOpenURL(url) {
        return true
    }

    return DeepLinkRouter.shared.handle(url)
}
```

Handle URLs in SceneDelegate:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }

    if Pushwoosh.configure.handleOpenURL(url) {
        return
    }

    DeepLinkRouter.shared.handle(url)
}
```

## See Also

- ``Pushwoosh/launchNotification``
