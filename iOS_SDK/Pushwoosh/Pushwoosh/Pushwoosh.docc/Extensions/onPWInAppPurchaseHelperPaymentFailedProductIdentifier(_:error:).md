# ``PWPurchaseDelegate/onPWInAppPurchaseHelperPaymentFailedProductIdentifier(_:error:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tells the delegate that the transaction was cancelled or failed before being added to the server queue.

## Overview

This method is called when a purchase transaction fails or is cancelled by the user. Use this to handle errors, display appropriate messages to the user, or log the failure for analytics.

Common reasons for failure include user cancellation, invalid product IDs, or network issues.

## Example

Handle purchase failure with appropriate user feedback:

```swift
class PurchaseManager: NSObject, PWPurchaseDelegate {

    func onPWInAppPurchaseHelperPaymentFailedProductIdentifier(_ identifier: String, error: Error) {
        let skError = error as? SKError

        analytics.track("purchase_failed", properties: [
            "product_id": identifier,
            "error_code": skError?.code.rawValue ?? -1,
            "error_message": error.localizedDescription
        ])

        DispatchQueue.main.async {
            self.handlePurchaseError(skError, productId: identifier)
        }
    }

    private func handlePurchaseError(_ error: SKError?, productId: String) {
        switch error?.code {
        case .paymentCancelled:
            break
        case .paymentNotAllowed:
            showAlert(title: "Purchase Not Allowed",
                     message: "In-app purchases are disabled on this device.")
        case .storeProductNotAvailable:
            showAlert(title: "Product Unavailable",
                     message: "This item is currently unavailable in your region.")
        default:
            showAlert(title: "Purchase Failed",
                     message: "Please try again later.")
        }
    }
}
```

## See Also

- ``PWPurchaseDelegate/onPWInAppPurchaseHelperPaymentComplete(_:)``
