# ``Pushwoosh/sendSKPaymentTransactions(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Sends in-app purchase transactions to Pushwoosh.

## Discussion

Tracks in-app purchases by forwarding StoreKit payment transactions to Pushwoosh. This enables purchase-based analytics and user segmentation.

Call this method from your `SKPaymentTransactionObserver`'s `paymentQueue:updatedTransactions:` method to automatically track all purchases.

## Parameters

- transactions: Array of SKPaymentTransaction items received from the payment queue
