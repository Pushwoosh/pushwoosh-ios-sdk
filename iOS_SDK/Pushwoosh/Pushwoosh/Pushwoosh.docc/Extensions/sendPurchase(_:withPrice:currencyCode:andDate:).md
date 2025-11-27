# ``Pushwoosh/sendPurchase(_:withPrice:currencyCode:andDate:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tracks an individual in-app purchase.

## Overview

Manually reports a purchase to Pushwoosh for:
- Revenue analytics
- Purchase-based segmentation
- Conversion tracking
- LTV calculations

## Automatic vs Manual Tracking

For StoreKit purchases, prefer ``sendSKPaymentTransactions(_:)`` which handles tracking automatically. Use this method for:
- Custom payment systems (Stripe, RevenueCat, etc.)
- Server-side purchase verification
- Non-StoreKit purchases

## Example

Track purchase from custom payment system:

```swift
func handlePurchaseComplete(product: Product, transaction: PaymentTransaction) {
    Pushwoosh.configure.sendPurchase(
        product.identifier,
        withPrice: NSDecimalNumber(decimal: transaction.amount),
        currencyCode: transaction.currency,
        andDate: transaction.date
    )

    Analytics.log("purchase_tracked", [
        "product": product.identifier,
        "amount": transaction.amount
    ])
}
```

Track subscription purchase:

```swift
func trackSubscriptionPurchase(subscription: Subscription) {
    Pushwoosh.configure.sendPurchase(
        subscription.productId,
        withPrice: NSDecimalNumber(value: subscription.price),
        currencyCode: subscription.currencyCode,
        andDate: Date()
    )

    Pushwoosh.configure.setTags([
        "subscription_tier": subscription.tier,
        "subscription_expiry": subscription.expiryDate
    ])
}
```

## See Also

- ``Pushwoosh/sendSKPaymentTransactions(_:)``
- ``Pushwoosh/setTags(_:)``
