# ``PWPurchaseDelegate/onPWInAppPurchaseHelperPaymentFailedProductIdentifier(_:error:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tells the delegate that the transaction was cancelled or failed before being added to the server queue.

## Discussion

This method is called when a purchase transaction fails or is cancelled by the user. Use this to handle errors, display appropriate messages to the user, or log the failure for analytics.

Common reasons for failure include user cancellation, invalid product IDs, or network issues.

## Parameters

- identifier: The unique product identifier
- error: The error that caused the transaction to fail
