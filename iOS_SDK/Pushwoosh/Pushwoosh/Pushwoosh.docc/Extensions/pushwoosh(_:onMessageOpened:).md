# ``PWMessagingDelegate/pushwoosh(_:onMessageOpened:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Called when the user taps on a push notification.

## Overview

This method is invoked when a user explicitly taps on a notification banner or notification in the Notification Center. Use this method to:
- Navigate to relevant content
- Open deep links
- Track user engagement with notifications
- Perform actions based on notification type

## Timing

This method is called:
- When user taps notification while app is in background
- When user taps notification while app is terminated (app is launched first)
- NOT called for silent/background notifications

## Example

Handle deep links from notification:

```swift
func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
    Analytics.log("push_opened", [
        "campaign_id": message.customData?["campaign_id"] ?? ""
    ])

    guard let customData = message.customData else { return }

    if let deepLink = customData["deep_link"] as? String,
       let url = URL(string: deepLink) {
        DeepLinkRouter.shared.handle(url)
        return
    }

    if let screen = customData["screen"] as? String {
        navigateToScreen(screen, params: customData)
    }
}

private func navigateToScreen(_ screen: String, params: [AnyHashable: Any]) {
    switch screen {
    case "order_details":
        if let orderId = params["order_id"] as? String {
            router.push(OrderDetailsViewController(orderId: orderId))
        }
    case "product":
        if let productId = params["product_id"] as? String {
            router.push(ProductViewController(productId: productId))
        }
    case "promo":
        if let promoCode = params["promo_code"] as? String {
            router.push(PromoViewController(code: promoCode))
        }
    default:
        break
    }
}
```

Open specific tab when notification is tapped:

```swift
func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
    guard let tabIndex = message.customData?["tab"] as? Int else { return }

    if let tabBarController = window?.rootViewController as? UITabBarController {
        tabBarController.selectedIndex = tabIndex
    }
}
```

## See Also

- ``PWMessagingDelegate/pushwoosh(_:onMessageReceived:)``
- ``PWMessage``
- ``Pushwoosh/delegate``
