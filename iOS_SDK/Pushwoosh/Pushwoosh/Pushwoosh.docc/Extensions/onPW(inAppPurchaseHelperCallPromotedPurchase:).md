# ``PWPurchaseDelegate/onPW(inAppPurchaseHelperCallPromotedPurchase:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tells the delegate that a user initiates an IAP buy from the App Store.

## Discussion

This method is called when a user initiates an in-app purchase directly from the App Store (promoted IAP). Use this to handle the promoted purchase flow and start the transaction.

## Parameters

- identifier: Product identifier of the promoted product
