# ``Pushwoosh/purchaseDelegate``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Delegate that receives in-app purchase events from rich media.

## Overview

Set this property to handle purchase events triggered from Pushwoosh rich media notifications. The delegate receives callbacks for:
- Product information requests
- Successful purchases
- Failed payments
- Promoted purchases
- Transaction restoration failures

## Platform

This property is only available on iOS.

## Example

Set up purchase delegate:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.configure.delegate = self
    Pushwoosh.configure.purchaseDelegate = self
    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Use a dedicated purchase handler:

```swift
class PurchaseHandler: NSObject, PWPurchaseDelegate {
    static let shared = PurchaseHandler()

    func onPWInAppPurchaseHelperPaymentComplete(_ identifier: String?) {
        guard let identifier = identifier else { return }
        PremiumManager.shared.unlock(productId: identifier)
    }
}

// In AppDelegate
Pushwoosh.configure.purchaseDelegate = PurchaseHandler.shared
```

## See Also

- ``PWPurchaseDelegate``
- ``Pushwoosh/delegate``
