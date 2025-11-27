# ``PWPurchaseDelegate/onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tells the delegate that an error occurred while restoring transactions.

## Overview

This method is called when the restore purchases operation fails. Use this to inform the user that their purchases could not be restored and provide appropriate error handling.

## Example

Handle restore failure with user feedback:

```swift
class PurchaseManager: NSObject, PWPurchaseDelegate {

    func onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed(_ error: Error) {
        analytics.track("restore_purchases_failed", properties: [
            "error": error.localizedDescription
        ])

        DispatchQueue.main.async {
            self.hideLoadingIndicator()

            let skError = error as? SKError
            switch skError?.code {
            case .paymentCancelled:
                break
            case .cloudServiceNetworkConnectionFailed:
                self.showAlert(
                    title: "Network Error",
                    message: "Please check your internet connection and try again."
                )
            default:
                self.showAlert(
                    title: "Restore Failed",
                    message: "Unable to restore purchases. Please try again or contact support."
                )
            }
        }
    }
}
```

## See Also

- ``PWPurchaseDelegate/onPWInAppPurchaseHelperPaymentComplete(_:)``
