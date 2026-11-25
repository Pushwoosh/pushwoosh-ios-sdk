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
        Pushwoosh.configure.registerForPushNotifications()

        return true
    }

    func onPW(inAppPurchaseHelperProducts products: [SKProduct]?) {
        guard let products = products else { return }

        for product in products {
            ProductStore.shared.cache(product)
        }
    }

    func onPW(inAppPurchaseHelperPaymentComplete identifier: String?) {
        guard let identifier = identifier else { return }

        Analytics.log("purchase_complete", ["product": identifier])
        PremiumManager.shared.unlock(productId: identifier)
    }

    func onPW(inAppPurchaseHelperPaymentFailedProductIdentifier identifier: String?, error: Error?) {
        Analytics.log("purchase_failed", [
            "product": identifier ?? "",
            "error": error?.localizedDescription ?? ""
        ])
    }

    func onPW(inAppPurchaseHelperCallPromotedPurchase identifier: String?) {
        guard let identifier = identifier else { return }

        showPurchaseConfirmation(for: identifier)
    }

    func onPW(inAppPurchaseHelperRestoreCompletedTransactionsFailed error: Error?) {
        showError("Failed to restore purchases: \(error?.localizedDescription ?? "Unknown error")")
    }
}
```

## Topics

### Product Information

- ``PWPurchaseDelegate/onPW(inAppPurchaseHelperProducts:)``

### Purchase Events

- ``PWPurchaseDelegate/onPW(inAppPurchaseHelperPaymentComplete:)``
- ``PWPurchaseDelegate/onPW(inAppPurchaseHelperPaymentFailedProductIdentifier:error:)``
- ``PWPurchaseDelegate/onPW(inAppPurchaseHelperCallPromotedPurchase:)``

### Restore Transactions

- ``PWPurchaseDelegate/onPW(inAppPurchaseHelperRestoreCompletedTransactionsFailed:)``
