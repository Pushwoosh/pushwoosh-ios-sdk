# ``Pushwoosh/sendPurchase(_:withPrice:currencyCode:andDate:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tracks an individual in-app purchase.

## Discussion

Manually reports a single in-app purchase to Pushwoosh for analytics and segmentation. For automatic tracking, use the recommended `sendSKPaymentTransactions:` method instead.

This method is useful when you need granular control over purchase tracking or are using a non-standard payment system.

## Parameters

- productIdentifier: The purchased product ID
- price: The price paid for the product
- currencyCode: The currency code (e.g., "USD", "EUR")
- date: The time of purchase
