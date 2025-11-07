# ``PWPurchaseDelegate/onPWInAppPurchaseHelperPaymentComplete(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tells the delegate that the transaction is in queue and the user has been charged.

## Discussion

This method is called when a purchase transaction completes successfully. The transaction has been added to the payment queue and the user's account has been charged.

Use this method to unlock content, update your app's state, or provide confirmation to the user.

## Parameters

- identifier: Product identifier agreed upon with the store
