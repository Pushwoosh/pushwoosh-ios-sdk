# ``Pushwoosh/sendSKPaymentTransactions(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sends in-app purchase transactions to Pushwoosh.

## Overview

Automatically tracks StoreKit purchases for:
- Revenue analytics in Pushwoosh Control Panel
- Purchase-based user segmentation
- Conversion tracking
- LTV (Lifetime Value) calculations

This is the recommended method for tracking StoreKit purchases.

## Example

Track purchases in payment queue observer:

```swift
class StoreManager: NSObject, SKPaymentTransactionObserver {

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        Pushwoosh.configure.sendSKPaymentTransactions(transactions)

        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                handlePurchase(transaction)
                queue.finishTransaction(transaction)
            case .failed:
                handleFailure(transaction)
                queue.finishTransaction(transaction)
            case .restored:
                handleRestore(transaction)
                queue.finishTransaction(transaction)
            default:
                break
            }
        }
    }
}
```

Filter transactions before sending:

```swift
func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    let completedTransactions = transactions.filter {
        $0.transactionState == .purchased || $0.transactionState == .restored
    }

    if !completedTransactions.isEmpty {
        Pushwoosh.configure.sendSKPaymentTransactions(completedTransactions)
    }
}
```

## See Also

- ``Pushwoosh/sendPurchase(_:withPrice:currencyCode:andDate:)``
- ``PWPurchaseDelegate``
