# ``PWPurchaseDelegate/onPWInAppPurchaseHelperProducts(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tells the delegate that the application received the array of products.

## Discussion

This method is called when StoreKit returns available products for in-app purchases initiated from rich media. Use this to display product information or prepare the purchase flow.

## Parameters

- products: Array of SKProduct instances representing available products
