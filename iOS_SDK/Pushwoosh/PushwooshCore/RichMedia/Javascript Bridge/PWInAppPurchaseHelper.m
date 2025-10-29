//
//  PWInAppPurchaseHelper.m
//  Pushwoosh
//
//  Created by Vitaly Romanychev on 19.08.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//
#import "PWInAppPurchaseHelper.h"
#import "PWInAppManager.h"
#import <PushwooshCore/PWManagerBridge.h>

#if TARGET_OS_IOS
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

    if ([[PWManagerBridge shared].purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperProducts:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [[PWManagerBridge shared].purchaseDelegate performSelector:@selector(onPWInAppPurchaseHelperProducts:) withObject:self.products];
#pragma clang diagnostic pop
    }
    for (NSString *invalidIdentifier in response.invalidProductIdentifiers)
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:[NSString stringWithFormat:@"PWInAppPurchaseHelper - Invalid identifier : %@", invalidIdentifier]];
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
                if ([[PWManagerBridge shared].purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperPaymentComplete:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [[PWManagerBridge shared].purchaseDelegate performSelector:@selector(onPWInAppPurchaseHelperPaymentComplete:) withObject:transaction.payment.productIdentifier];
#pragma clang diagnostic pop
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                if ([[PWManagerBridge shared].purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperPaymentFailedProductIdentifier:error:)]) {
                    id delegate = [PWManagerBridge shared].purchaseDelegate;
                    SEL selector = @selector(onPWInAppPurchaseHelperPaymentFailedProductIdentifier:error:);
                    NSMethodSignature *signature = [delegate methodSignatureForSelector:selector];
                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                    [invocation setSelector:selector];
                    [invocation setTarget:delegate];

                    NSString *transactionId = transaction.transactionIdentifier;
                    NSError *error = transaction.error;
                    [invocation setArgument:&transactionId atIndex:2];
                    [invocation setArgument:&error atIndex:3];
                    [invocation invoke];
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                if ([[PWManagerBridge shared].purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperPaymentComplete:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [[PWManagerBridge shared].purchaseDelegate performSelector:@selector(onPWInAppPurchaseHelperPaymentComplete:) withObject:transaction.payment.productIdentifier];
#pragma clang diagnostic pop
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
    if ([[PWManagerBridge shared].purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperCallPromotedPurchase:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [[PWManagerBridge shared].purchaseDelegate performSelector:@selector(onPWInAppPurchaseHelperCallPromotedPurchase:) withObject:product.productIdentifier];
#pragma clang diagnostic pop
    }
    return YES;
}

#pragma mark - Restore Completed Transactions Failed

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    if ([[PWManagerBridge shared].purchaseDelegate respondsToSelector:@selector(onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [[PWManagerBridge shared].purchaseDelegate performSelector:@selector(onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:) withObject:error];
#pragma clang diagnostic pop
    }
}

@end
#endif
