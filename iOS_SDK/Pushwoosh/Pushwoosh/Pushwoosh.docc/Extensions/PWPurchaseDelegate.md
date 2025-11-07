# ``PWPurchaseDelegate``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Delegate protocol for handling in-app purchase events from rich media.

## Discussion

The `PWPurchaseDelegate` protocol defines methods for responding to in-app purchase events initiated from Pushwoosh rich media notifications. These methods provide callbacks for successful purchases, failed payments, and other purchase-related events.

Implement these methods to handle purchase flow and update your app's state accordingly.

Set your purchase delegate on the shared Pushwoosh instance:

```swift
Pushwoosh.sharedInstance().purchaseDelegate = self
```

## Topics

### Product Information

- ``onPWInAppPurchaseHelperProducts:``

### Purchase Events

- ``onPWInAppPurchaseHelperPaymentComplete:``
- ``onPWInAppPurchaseHelperPaymentFailedProductIdentifier:error:``
- ``onPWInAppPurchaseHelperCallPromotedPurchase:``

### Restore Transactions

- ``onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:``
