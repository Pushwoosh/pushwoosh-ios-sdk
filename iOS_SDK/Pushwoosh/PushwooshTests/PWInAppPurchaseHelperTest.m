#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PushwooshFramework.h"

#import "PWInAppPurchaseHelper.h"

@interface PWInAppPurchaseHelperTest : XCTestCase <PWPurchaseDelegate>

@property (nonatomic) PWInAppPurchaseHelper *purchaseHelper;
@property (nonatomic, weak) id<PWPurchaseDelegate> originalPurchaseDelegate;

@end

@interface PWInAppPurchaseHelper (TEST)

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response;
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error;
- (BOOL)paymentQueue:(SKPaymentQueue *)queue shouldAddStorePayment:(SKPayment *)payment forProduct:(SKProduct *)product;

@end

@implementation PWInAppPurchaseHelperTest

- (void)setUp {
    [super setUp];
    _purchaseHelper = [PWInAppPurchaseHelper sharedInstance];
    _originalPurchaseDelegate = [Pushwoosh sharedInstance].purchaseDelegate;
    [[Pushwoosh sharedInstance] setPurchaseDelegate:self];
}

- (void)tearDown {
    [[Pushwoosh sharedInstance] setPurchaseDelegate:_originalPurchaseDelegate];
    [super tearDown];
}

/// Verifies that productsRequest:didReceiveResponse: forwards received products to the purchase delegate.
- (void)testOnPWInAppPurchaseHelperProducts {
    SKProductsRequest *productRequest = [[SKProductsRequest alloc] init];
    SKProductsResponse *productResponse = [[SKProductsResponse alloc] init];
    id mockProducts = OCMPartialMock(productResponse);
    SKProduct *pr = [[SKProduct alloc] init];
    id mockPr = OCMPartialMock(pr);
    OCMStub([mockPr productIdentifier]).andReturn(@"pushwoosh_purchase_test");
    NSArray<SKProduct *> *products = @[pr];
    OCMStub([mockProducts products]).andReturn(products);
    id mockDelegate = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockDelegate onPWInAppPurchaseHelperProducts:products]);

    [self.purchaseHelper productsRequest:productRequest didReceiveResponse:productResponse];

    OCMVerifyAll(mockDelegate);

    [mockDelegate stopMocking];
    [mockProducts stopMocking];
    [mockPr stopMocking];
}

/// Verifies that a purchased transaction triggers onPaymentComplete and finishes the transaction on the default queue.
- (void)testOnPWInAppPurchaseHelperPaymentComplete {
    SKPaymentQueue *queue = [[SKPaymentQueue alloc] init];
    SKPaymentTransaction *transaction = [[SKPaymentTransaction alloc] init];
    NSArray *transactions = @[transaction];
    id mockTransaction = OCMPartialMock(transaction);
    OCMStub([mockTransaction transactionState]).andReturn(SKPaymentTransactionStatePurchased);
    id mockDelegate = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockDelegate onPWInAppPurchaseHelperPaymentComplete:OCMOCK_ANY]);
    id mockQueue = OCMPartialMock([SKPaymentQueue defaultQueue]);
    OCMExpect([mockQueue finishTransaction:OCMOCK_ANY]);

    [self.purchaseHelper paymentQueue:queue updatedTransactions:transactions];

    OCMVerifyAll(mockDelegate);
    OCMVerifyAll(mockQueue);

    [mockTransaction stopMocking];
    [mockDelegate stopMocking];
    [mockQueue stopMocking];
}

/// Verifies that a failed transaction triggers onPaymentFailed and finishes the transaction on the default queue.
- (void)testOnPWInAppPurchaseHelperPaymentFailedProductIdentifier {
    SKPaymentQueue *queue = [[SKPaymentQueue alloc] init];
    SKPaymentTransaction *transaction = [[SKPaymentTransaction alloc] init];
    NSArray *transactions = @[transaction];
    id mockTransaction = OCMPartialMock(transaction);
    OCMStub([mockTransaction transactionState]).andReturn(SKPaymentTransactionStateFailed);
    id mockDelegate = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockDelegate onPWInAppPurchaseHelperPaymentFailedProductIdentifier:OCMOCK_ANY error:OCMOCK_ANY]);
    id mockQueue = OCMPartialMock([SKPaymentQueue defaultQueue]);
    OCMExpect([mockQueue finishTransaction:OCMOCK_ANY]);

    [self.purchaseHelper paymentQueue:queue updatedTransactions:transactions];

    OCMVerifyAll(mockDelegate);
    OCMVerifyAll(mockQueue);

    [mockTransaction stopMocking];
    [mockDelegate stopMocking];
    [mockQueue stopMocking];
}

/// Verifies that a restored transaction also triggers onPaymentComplete and finishes the transaction.
- (void)testOnPWInAppPurchaseHelperPaymentCompleteForRestoredTransaction {
    SKPaymentQueue *queue = [[SKPaymentQueue alloc] init];
    SKPaymentTransaction *transaction = [[SKPaymentTransaction alloc] init];
    NSArray *transactions = @[transaction];
    id mockTransaction = OCMPartialMock(transaction);
    OCMStub([mockTransaction transactionState]).andReturn(SKPaymentTransactionStateRestored);
    id mockDelegate = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockDelegate onPWInAppPurchaseHelperPaymentComplete:OCMOCK_ANY]);
    id mockQueue = OCMPartialMock([SKPaymentQueue defaultQueue]);
    OCMExpect([mockQueue finishTransaction:OCMOCK_ANY]);

    [self.purchaseHelper paymentQueue:queue updatedTransactions:transactions];

    OCMVerifyAll(mockDelegate);
    OCMVerifyAll(mockQueue);

    [mockTransaction stopMocking];
    [mockDelegate stopMocking];
    [mockQueue stopMocking];
}

/// Verifies that restoreCompletedTransactionsFailedWithError forwards the error to the delegate.
- (void)testRestoreCompletedTransactionsFailedWithErrorCallback {
    SKPaymentQueue *queue = [[SKPaymentQueue alloc] init];
    NSError *error = [NSError errorWithDomain:@"Domain" code:404 userInfo:@{}];
    id mockDelegate = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockDelegate onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:OCMOCK_ANY]);

    [self.purchaseHelper paymentQueue:queue restoreCompletedTransactionsFailedWithError:error];

    OCMVerifyAll(mockDelegate);

    [mockDelegate stopMocking];
}

/// Verifies that a promoted-purchase invitation from the store is delivered to the delegate.
- (void)testOnPWInAppPurchaseHelperCallPromotedPurchase {
    SKPaymentQueue *queue = [[SKPaymentQueue alloc] init];
    SKPayment *payment = [[SKPayment alloc] init];
    SKProduct *product = [[SKProduct alloc] init];
    id mockDelegate = OCMPartialMock([Pushwoosh sharedInstance].purchaseDelegate);
    OCMExpect([mockDelegate onPWInAppPurchaseHelperCallPromotedPurchase:OCMOCK_ANY]);

    [self.purchaseHelper paymentQueue:queue shouldAddStorePayment:payment forProduct:product];

    OCMVerifyAll(mockDelegate);

    [mockDelegate stopMocking];
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
