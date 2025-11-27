# ``PWPurchaseDelegate/onPWInAppPurchaseHelperPaymentComplete(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tells the delegate that the transaction is in queue and the user has been charged.

## Overview

This method is called when a purchase transaction completes successfully. The transaction has been added to the payment queue and the user's account has been charged.

Use this method to unlock content, update your app's state, or provide confirmation to the user.

## Example

Handle successful purchase:

```swift
class PurchaseManager: NSObject, PWPurchaseDelegate {

    func onPWInAppPurchaseHelperPaymentComplete(_ identifier: String) {
        unlockPurchasedContent(identifier)

        Pushwoosh.configure.setTags([
            "purchased_\(identifier)": true,
            "last_purchase_date": Date()
        ])

        analytics.track("purchase_complete", properties: [
            "product_id": identifier
        ])

        DispatchQueue.main.async {
            self.showPurchaseConfirmation(productId: identifier)
        }
    }

    private func unlockPurchasedContent(_ identifier: String) {
        switch identifier {
        case "premium_monthly", "premium_yearly":
            userManager.upgradeToPremium()
        case "remove_ads":
            adManager.disableAds()
        default:
            contentManager.unlock(identifier)
        }
    }
}
```

## See Also

- ``PWPurchaseDelegate/onPWInAppPurchaseHelperPaymentFailedProductIdentifier(_:error:)``
- ``PWPurchaseDelegate/onPW(inAppPurchaseHelperCallPromotedPurchase:)``
