# ``PWPurchaseDelegate``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Delegate protocol for handling in-app purchase events from rich media.

## Overview

Implement `PWPurchaseDelegate` to respond to in-app purchase events initiated from Pushwoosh rich media notifications. This enables:
- Promotional purchases from push notifications
- Product information display
- Purchase completion handling
- Error handling for failed transactions

## Implementation

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, PWPurchaseDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Pushwoosh.configure.purchaseDelegate = self
        Pushwoosh.configure.delegate = self
        Pushwoosh.configure.registerForPushNotifications()

        return true
    }

    func onPWInAppPurchaseHelperProducts(_ products: [SKProduct]?) {
        guard let products = products else { return }

        for product in products {
            ProductStore.shared.cache(product)
        }
    }

    func onPWInAppPurchaseHelperPaymentComplete(_ identifier: String?) {
        guard let identifier = identifier else { return }

        Analytics.log("purchase_complete", ["product": identifier])
        PremiumManager.shared.unlock(productId: identifier)
    }

    func onPWInAppPurchaseHelperPaymentFailed(productIdentifier identifier: String?, error: Error?) {
        Analytics.log("purchase_failed", [
            "product": identifier ?? "",
            "error": error?.localizedDescription ?? ""
        ])
    }

    func onPWInAppPurchaseHelperCallPromotedPurchase(_ identifier: String?) {
        guard let identifier = identifier else { return }

        showPurchaseConfirmation(for: identifier)
    }

    func onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed(_ error: Error?) {
        showError("Failed to restore purchases: \(error?.localizedDescription ?? "Unknown error")")
    }
}
```

## Topics

### Product Information

- ``onPWInAppPurchaseHelperProducts(_:)``

### Purchase Events

- ``onPWInAppPurchaseHelperPaymentComplete(_:)``
- ``onPWInAppPurchaseHelperPaymentFailedProductIdentifier(_:error:)``
- ``onPW(inAppPurchaseHelperCallPromotedPurchase:)``

### Restore Transactions

- ``onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed(_:)``
