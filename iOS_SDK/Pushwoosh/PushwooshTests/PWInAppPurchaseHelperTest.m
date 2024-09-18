//
//  PWInAppPurchaseHelper.m
//  PushwooshTests
//
//  Created by Andrei Kiselev on 30.8.22..
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PushwooshFramework.h"

#import "PWInAppPurchaseHelper.h"

@interface PWInAppPurchaseHelperTest : XCTestCase <PWPurchaseDelegate>

@property (nonatomic) PWInAppPurchaseHelper *purchaseHelper;

@end

@interface PWInAppPurchaseHelper (TEST)

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response;
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error;
- (BOOL)paymentQueue:(SKPaymentQueue *)queue shouldAddStorePayment:(SKPayment *)payment forProduct:(SKProduct *)product;

@end

@implementation PWInAppPurchaseHelperTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _purchaseHelper =  [PWInAppPurchaseHelper sharedInstance];
    [[Pushwoosh sharedInstance] setPurchaseDelegate:self];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testOnPWInAppPurchaseHelperProducts {
    SKProductsRequest *productRequest = [[SKProductsRequest alloc] init];
    SKProductsResponse *productResponse = [[SKProductsResponse alloc] init];
    id mockProducts = OCMPartialMock(productResponse);
    SKProduct *pr = [[SKProduct alloc] init];
    id mockPr = OCMPartialMock(pr);
    OCMStub([mockPr productIdentifier]).andReturn(@"pushwoosh_purchase_test");
    NSArray<SKProduct *> *products = @[pr];
    OCMStub([mockProducts products]).andReturn(products);
    id mockPushwooshSharedInstance = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockPushwooshSharedInstance onPWInAppPurchaseHelperProducts:products]);
    
    [self.purchaseHelper productsRequest:productRequest didReceiveResponse:productResponse];
    
    OCMVerifyAll(mockPushwooshSharedInstance);
}

- (void)testOnPWInAppPurchaseHelperPaymentComplete {
    SKPaymentQueue *queue = [[SKPaymentQueue alloc] init];
    SKPaymentTransaction *transaction = [[SKPaymentTransaction alloc] init];
    NSArray *transactions = @[transaction];
    id mockSKPaymentTransaction = OCMPartialMock(transaction);
    OCMStub([mockSKPaymentTransaction transactionState]).andReturn(SKPaymentTransactionStatePurchased);
    id mockPushwooshSharedInstance = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockPushwooshSharedInstance onPWInAppPurchaseHelperPaymentComplete:OCMOCK_ANY]);
    id mockSKPaymentQueue = OCMPartialMock([SKPaymentQueue defaultQueue]);
    OCMExpect([mockSKPaymentQueue finishTransaction:OCMOCK_ANY]);
    
    [self.purchaseHelper paymentQueue:queue updatedTransactions:transactions];
    
    OCMVerifyAll(mockPushwooshSharedInstance);
    OCMVerifyAll(mockSKPaymentQueue);
}

- (void)testOnPWInAppPurchaseHelperPaymentFailedProductIdentifier {
    SKPaymentQueue *queue = [[SKPaymentQueue alloc] init];
    SKPaymentTransaction *transaction = [[SKPaymentTransaction alloc] init];
    NSArray *transactions = @[transaction];
    id mockSKPaymentTransaction = OCMPartialMock(transaction);
    OCMStub([mockSKPaymentTransaction transactionState]).andReturn(SKPaymentTransactionStateFailed);
    id mockPushwooshSharedInstance = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockPushwooshSharedInstance onPWInAppPurchaseHelperPaymentFailedProductIdentifier:OCMOCK_ANY error:OCMOCK_ANY]);
    id mockSKPaymentQueue = OCMPartialMock([SKPaymentQueue defaultQueue]);
    OCMExpect([mockSKPaymentQueue finishTransaction:OCMOCK_ANY]);
    
    [self.purchaseHelper paymentQueue:queue updatedTransactions:transactions];
    
    OCMVerifyAll(mockPushwooshSharedInstance);
    OCMVerifyAll(mockSKPaymentQueue);
}

- (void)testOnPWInAppPurchaseHelperPaymentCompleteForRestoredTransaction {
    SKPaymentQueue *queue = [[SKPaymentQueue alloc] init];
    SKPaymentTransaction *transaction = [[SKPaymentTransaction alloc] init];
    NSArray *transactions = @[transaction];
    id mockSKPaymentTransaction = OCMPartialMock(transaction);
    OCMStub([mockSKPaymentTransaction transactionState]).andReturn(SKPaymentTransactionStateRestored);
    id mockPushwooshSharedInstance = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockPushwooshSharedInstance onPWInAppPurchaseHelperPaymentComplete:OCMOCK_ANY]);
    id mockSKPaymentQueue = OCMPartialMock([SKPaymentQueue defaultQueue]);
    OCMExpect([mockSKPaymentQueue finishTransaction:OCMOCK_ANY]);
    
    [self.purchaseHelper paymentQueue:queue updatedTransactions:transactions];
    
    OCMVerifyAll(mockPushwooshSharedInstance);
    OCMVerifyAll(mockSKPaymentQueue);
}

- (void)testRestoreCompletedTransactionsFailedWithErrorCallback {
    SKPaymentQueue *queue = [[SKPaymentQueue alloc] init];
    NSError *error = [NSError errorWithDomain:@"Domain" code:404 userInfo:@{}];
    id mockPushwooshSharedInstance = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockPushwooshSharedInstance onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:OCMOCK_ANY]);

    [self.purchaseHelper paymentQueue:queue restoreCompletedTransactionsFailedWithError:error];
    
    OCMVerifyAll(mockPushwooshSharedInstance);
}

- (void)testOnPWInAppPurchaseHelperCallPromotedPurchase {
    SKPaymentQueue *queue = [[SKPaymentQueue alloc] init];
    SKPayment *payment = [[SKPayment alloc] init];
    SKProduct *product = [[SKProduct alloc] init];
    id mockPushwooshSharedInstance = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockPushwooshSharedInstance onPWInAppPurchaseHelperCallPromotedPurchase:OCMOCK_ANY]);
    
    [self.purchaseHelper paymentQueue:queue shouldAddStorePayment:payment forProduct:product];
    
    OCMVerifyAll(mockPushwooshSharedInstance);
}

- (void)onPWInAppPurchaseHelperCallPromotedPurchase:(NSString *)identifier {
    
}

- (void)onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:(NSError *)error {
    
}

- (void)onPWInAppPurchaseHelperProducts:(NSArray<SKProduct *> *)products {
    
}

- (void)onPWInAppPurchaseHelperPaymentComplete:(NSString *)identifier {
    
}

- (void)onPWInAppPurchaseHelperPaymentFailedProductIdentifier:(NSString *)identifier error:(NSError *)error {
    
}

@end
