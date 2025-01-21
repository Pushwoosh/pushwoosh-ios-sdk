//
//  PWInAppPurchaseHelper.m
//  Pushwoosh
//
//  Created by Vitaly Romanychev on 19.08.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//
#import "PWInAppPurchaseHelper.h"
#import "PushwooshFramework.h"
#import "PWInAppManager.h"

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface PWInAppPurchaseHelper() <SKProductsRequestDelegate, SKPaymentTransactionObserver, SKRequestDelegate>

@property (nonatomic, strong) SKProductsRequest *request;
@property (nonatomic, strong) NSArray<SKProduct *> *products;

@end

@implementation PWInAppPurchaseHelper

+ (PWInAppPurchaseHelper *)sharedInstance {
    static PWInAppPurchaseHelper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (BOOL)canMakePayments {
    return [SKPaymentQueue canMakePayments];
}

#pragma mark - validateProduct

- (void)validateProductIdentifiers:(NSArray *)productIdentifiers {
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                          initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
    
    self.request = productsRequest;
    productsRequest.delegate = self;
    [productsRequest start];
}

#pragma mark SKProduct delegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    self.products = response.products;
    
    if ([Pushwoosh.sharedInstance.purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperProducts:)]) {
        [Pushwoosh.sharedInstance.purchaseDelegate onPWInAppPurchaseHelperProducts:self.products];
    }
    for (NSString *invalidIdentifier in response.invalidProductIdentifiers)
        PWLogWarn(@"PWInAppPurchaseHelper - Invalid identifier : %@", invalidIdentifier);
}

#pragma mark - pay and restore

- (void)payWithIdentifier:(NSString*)identifier {
    for (SKProduct *product in self.products) {
        if ([product.productIdentifier isEqualToString:identifier]) {
            SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
            [[SKPaymentQueue defaultQueue] addPayment:payment];
        }
    }
}


- (void)refreshReceipt {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - responding to transaction statuses

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                if ([Pushwoosh.sharedInstance.purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperPaymentComplete:)]) {
                    [Pushwoosh.sharedInstance.purchaseDelegate onPWInAppPurchaseHelperPaymentComplete:transaction.payment.productIdentifier];
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                if ([Pushwoosh.sharedInstance.purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperPaymentFailedProductIdentifier:error:)]) {
                    [Pushwoosh.sharedInstance.purchaseDelegate onPWInAppPurchaseHelperPaymentFailedProductIdentifier:transaction.transactionIdentifier error:transaction.error];
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                if ([Pushwoosh.sharedInstance.purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperPaymentComplete:)]) {
                    [Pushwoosh.sharedInstance.purchaseDelegate onPWInAppPurchaseHelperPaymentComplete:transaction.payment.productIdentifier];
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            default:
                break;
        }
    }
}

#pragma mark - Promoted Purchase

- (BOOL)paymentQueue:(SKPaymentQueue *)queue shouldAddStorePayment:(SKPayment *)payment forProduct:(SKProduct *)product {
    if ([Pushwoosh.sharedInstance.purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperCallPromotedPurchase:)]) {
        [Pushwoosh.sharedInstance.purchaseDelegate onPWInAppPurchaseHelperCallPromotedPurchase:product.productIdentifier];
    }
    return YES;
}

#pragma mark - Restore Completed Transactions Failed

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    if ([Pushwoosh.sharedInstance.purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:)]) {
        [Pushwoosh.sharedInstance.purchaseDelegate onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:error];
    }
}

@end
