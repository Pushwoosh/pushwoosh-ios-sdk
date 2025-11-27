# ``PWPurchaseDelegate/onPWInAppPurchaseHelperProducts(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Tells the delegate that the application received the array of products.

## Overview

This method is called when StoreKit returns available products for in-app purchases initiated from rich media. Use this to display product information or prepare the purchase flow.

## Example

Display available products in purchase UI:

```swift
class PurchaseManager: NSObject, PWPurchaseDelegate {

    func onPWInAppPurchaseHelperProducts(_ products: [SKProduct]) {
        let availableProducts = products.map { product in
            ProductViewModel(
                identifier: product.productIdentifier,
                title: product.localizedTitle,
                description: product.localizedDescription,
                price: formatPrice(product)
            )
        }

        DispatchQueue.main.async {
            self.purchaseViewController?.updateProducts(availableProducts)
        }

        analytics.track("products_loaded", properties: [
            "product_count": products.count,
            "product_ids": products.map { $0.productIdentifier }
        ])
    }

    private func formatPrice(_ product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "\(product.price)"
    }
}
```

## See Also

- ``PWPurchaseDelegate/onPWInAppPurchaseHelperPaymentComplete(_:)``
- ``PWPurchaseDelegate/onPW(inAppPurchaseHelperCallPromotedPurchase:)``
