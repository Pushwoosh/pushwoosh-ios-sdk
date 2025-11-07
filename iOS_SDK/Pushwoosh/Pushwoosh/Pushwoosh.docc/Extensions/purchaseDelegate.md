# ``Pushwoosh/purchaseDelegate``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Delegate that receives in-app purchase events from rich media.

## Discussion

Set this property to an object conforming to `PWPurchaseDelegate` to receive callbacks about in-app purchase events initiated from Pushwoosh rich media notifications. The delegate receives information about product lists, successful purchases, failed payments, and transaction restoration.

This property is only available on iOS.

