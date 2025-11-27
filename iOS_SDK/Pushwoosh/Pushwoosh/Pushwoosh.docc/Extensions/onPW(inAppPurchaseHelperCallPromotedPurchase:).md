# ``PWPurchaseDelegate/onPW(inAppPurchaseHelperCallPromotedPurchase:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tells the delegate that a user initiates an IAP buy from the App Store.

## Overview

This method is called when a user initiates an in-app purchase directly from the App Store (promoted IAP). Use this to handle the promoted purchase flow and start the transaction.

Promoted purchases allow users to discover and buy in-app purchases directly from the App Store product page, before even launching your app.

## Example

Handle promoted purchase from App Store:

```swift
class PurchaseManager: NSObject, PWPurchaseDelegate {

    func onPW(inAppPurchaseHelperCallPromotedPurchase identifier: String) {
        analytics.track("promoted_purchase_initiated", properties: [
            "product_id": identifier
        ])

        if shouldDeferPurchase(identifier) {
            storeDeferredPurchase(identifier)
            showOnboardingFlow()
        } else {
            startPurchaseFlow(productIdentifier: identifier)
        }
    }

    private func shouldDeferPurchase(_ identifier: String) -> Bool {
        return !userManager.isLoggedIn || !onboardingManager.isComplete
    }
}
```

## See Also

- ``PWPurchaseDelegate/onPWInAppPurchaseHelperPaymentComplete(_:)``
- ``PWPurchaseDelegate/onPWInAppPurchaseHelperProducts(_:)``
