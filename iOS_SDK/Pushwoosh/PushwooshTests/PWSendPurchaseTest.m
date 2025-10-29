//
//  PWSendPurchaseTest.m
//  PushNotificationManager
//
//  Created by etkachenko on 12/22/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PushNotificationManager.h"
#import "PWNetworkModule.h"
#import "PWCache.h"
#import "PWTestUtils.h"
#import "PWRequestManagerMock.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"
#import "PWSendPurchaseRequest.h"
#import "PWPreferences.h"
#import "Pushwoosh+Internal.h"
#import "PWPostEventRequest.h"

#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>
#import <OCMock/OCMock.h>

@interface PWPurchaseManager (PWSendPurchaseTest)

@property (nonatomic, strong) NSMutableDictionary *productArray;  //productid => SKProduct mapping

- (void)sendSKPayments:(NSArray *)transactions;

@end

@interface PWSendPurchaseTest : XCTestCase

@property PushNotificationManager *pushManager;

@property (nonatomic, strong) PWRequestManager *originalRequestManager;

@property (nonatomic) PWPurchaseManager *purchaseManager;

@property (nonatomic, strong) PWRequestManagerMock *mockRequestManager;

@property (nonatomic, strong) PWNotificationManagerCompat *originalNotificationManager;

@end

@implementation PWSendPurchaseTest

- (void)setUp {
    [super setUp];
    
    [PWTestUtils setUp];
    
    self.originalRequestManager = [PWNetworkModule module].requestManager;
    self.mockRequestManager = [PWRequestManagerMock new];
    [PWNetworkModule module].requestManager = self.mockRequestManager;
    
    self.originalNotificationManager = [PWPlatformModule module].notificationManagerCompat;
    [PWPlatformModule module].notificationManagerCompat = mock([PWNotificationManagerCompat class]);
    
    [PushNotificationManager initializeWithAppCode:@"4FC89B6D14A655.46488481" appName:@"UnitTest"];
    self.pushManager = [PushNotificationManager pushManager];
    self.purchaseManager = [[PWPurchaseManager alloc] init];
}

- (void)tearDown {
    self.pushManager = nil;
    [PWNetworkModule module].requestManager = self.originalRequestManager;
    [PWPlatformModule module].notificationManagerCompat = self.originalNotificationManager;
    
    [PWTestUtils tearDown];
    
    [super tearDown];
}

- (void)testSendEmptyPurchase {
    XCTestExpectation *purchaseRequestExpectation = [self expectationWithDescription:@"purchaseRequestExpectation"];
    __block PWRequest *purchaseRequest = nil;
    
    self.mockRequestManager.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWPostEventRequest class]]) {
            purchaseRequest = request;
            [purchaseRequestExpectation fulfill];
        }
    };
    
    [self.pushManager sendPurchase:nil withPrice:nil currencyCode:nil andDate:nil];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    NSDictionary *requestDictionary = purchaseRequest.requestDictionary;
    NSDictionary *attributes = requestDictionary[@"attributes"];
    NSLog(@"%@", requestDictionary);
    XCTAssertEqualObjects([NSDecimalNumber zero], @0);
    XCTAssertEqualObjects(attributes[@"__currency"], @"USD");
    XCTAssertEqualObjects(attributes[@"productIdentifier"], @"unknowProduct");
    XCTAssertEqualObjects(attributes[@"transactionDate"], ([NSString stringWithFormat:@"%@", [NSDate date]]));
}

- (void)testSendPurchaseWithCorrectParameters {
    XCTestExpectation *purchaseRequestExpectation = [self expectationWithDescription:@"purchaseRequestExpectation"];
    NSString *productIdentifier = @"TestProductIdentifier";
    NSDecimalNumber *price = [NSDecimalNumber decimalNumberWithString:@"49.95"];
    NSString *currencyCode = @"EUR";
    NSDate *purchaseDate = [NSDate date];
    __block PWRequest *postEventRequest = nil;
    
    self.mockRequestManager.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWPostEventRequest class]]) {
            postEventRequest = request;
            [purchaseRequestExpectation fulfill];
        }
    };
    
    [self.pushManager sendPurchase:productIdentifier withPrice:price currencyCode:currencyCode andDate:purchaseDate];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    NSDictionary *requestDictionary = postEventRequest.requestDictionary;
    NSDictionary *attributes = requestDictionary[@"attributes"];
    NSLog(@"%@", requestDictionary);
    NSLog(@"%@", attributes[@"transactionDate"]);
    XCTAssertEqualObjects(requestDictionary[@"application"], [PWPreferences preferences].appCode);
    XCTAssertEqualObjects(requestDictionary[@"device_type"], @(DEVICE_TYPE));
    XCTAssertEqualObjects(requestDictionary[@"hwid"], [PWPreferences preferences].hwid);
    XCTAssertEqualObjects(requestDictionary[@"userId"], [PWPreferences preferences].userId);
    XCTAssertEqualObjects(requestDictionary[@"v"], PUSHWOOSH_VERSION);
    XCTAssertEqualObjects(attributes[@"__currency"], currencyCode);
    XCTAssertEqualObjects([self convertToNSNumber:price.stringValue], @49.95);
    XCTAssertEqualObjects(attributes[@"productIdentifier"], @"TestProductIdentifier");
    XCTAssertEqualObjects(attributes[@"quantity"], @1);
    XCTAssertEqualObjects(attributes[@"transactionDate"], ([NSString stringWithFormat:@"%@", [NSDate date]]));
    assertThat(attributes, hasKey(@"__amount"));
    assertThat(attributes, hasKey(@"__currency"));
    assertThat(attributes, hasKey(@"productIdentifier"));
    assertThat(attributes, hasKey(@"quantity"));
    assertThat(attributes, hasKey(@"status"));
    XCTAssertTrue([attributes[@"__amount"] isKindOfClass:[NSNumber class]]);
    XCTAssertTrue([attributes[@"quantity"] isKindOfClass:[NSNumber class]]);
}

- (NSNumber *)convertToNSNumber:(NSString *)number {
    NSDecimalNumber *dNumber = [NSDecimalNumber decimalNumberWithString:number];
    return (NSNumber *)dNumber;
}

- (NSString *)convertDateToString:(NSDate *)date {
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd"];
    return [dateFormat stringFromDate:date];
}

- (void)testSendPurchaseWithNegativePrice {
    XCTestExpectation *purchaseRequestExpectation = [self expectationWithDescription:@"purchaseRequestExpectation"];
    NSString *productIdentifier = @"TestProductIdentifier";
    NSDecimalNumber *price = [NSDecimalNumber decimalNumberWithString:@"-49.95"];
    NSString *currencyCode = @"EUR";
    NSDate *purchaseDate = [NSDate date];
    __block PWRequest *purchaseRequest = nil;
    
    self.mockRequestManager.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWPostEventRequest class]]) {
            purchaseRequest = request;
            [purchaseRequestExpectation fulfill];
        }
    };
    
    [self.pushManager sendPurchase:productIdentifier withPrice:price currencyCode:currencyCode andDate:purchaseDate];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    NSDictionary *requestDictionary = purchaseRequest.requestDictionary;
    NSDictionary *attributes = requestDictionary[@"attributes"];
    NSLog(@"%@", requestDictionary);
    XCTAssertEqualObjects(price, @-49.95);
    XCTAssertEqualObjects(attributes[@"__currency"], currencyCode);
    XCTAssertEqualObjects(attributes[@"transactionDate"], ([NSString stringWithFormat:@"%@", purchaseDate]));
}

- (void)testSendSKPaymentTransactions {
    id mockTransaction = OCMClassMock([SKPaymentTransaction class]);
    NSArray *transactions = [NSArray arrayWithObjects:mockTransaction, mockTransaction, nil];
    OCMStub([mockTransaction transactionState]).andReturn(SKPaymentTransactionStatePurchased);
    id mockSKPayment = OCMClassMock([SKPayment class]);
    OCMStub([mockTransaction payment]).andReturn(mockSKPayment);
    OCMStub([mockSKPayment productIdentifier]).andReturn(@"_product_identifier_test_");
    id mockNSMutableArray = OCMClassMock([NSMutableArray class]);
    id mockSKProductsRequest = OCMClassMock([SKProductsRequest class]);
    OCMStub([mockSKProductsRequest alloc]).andReturn(mockSKProductsRequest);
    OCMStub([mockSKProductsRequest initWithProductIdentifiers:OCMOCK_ANY]).andReturn(mockSKProductsRequest);
    OCMExpect([(SKProductsRequest *)mockSKProductsRequest start]);
    
    [self.pushManager sendSKPaymentTransactions:transactions];    
    
    OCMVerifyAll(mockSKProductsRequest);
    [mockTransaction stopMocking];
    [mockSKPayment stopMocking];
    [mockNSMutableArray stopMocking];
}

- (void)testSendSKPayments {
    id mockTransaction = OCMClassMock([SKPaymentTransaction class]);
    NSArray *transactions = [NSArray arrayWithObjects:mockTransaction, mockTransaction, nil];
    id mockSKPayment = OCMClassMock([SKPayment class]);
    OCMExpect([mockTransaction payment]).andReturn(mockSKPayment);
    OCMExpect([mockSKPayment productIdentifier]).andReturn(@"_product_identifier_test_");
    id mockSKProduct = OCMClassMock([SKProduct class]);
    self.purchaseManager.productArray = [[NSMutableDictionary alloc] init];
    [self.purchaseManager.productArray addEntriesFromDictionary:@{@"_product_identifier_test_": mockSKProduct}];
    OCMStub([(SKProduct *)mockSKProduct price]).andReturn([NSDecimalNumber decimalNumberWithString:@"123.21"]);
    id mockNSLocale = OCMClassMock([NSLocale class]);
    OCMStub([(SKProduct *)mockSKProduct priceLocale]).andReturn(mockNSLocale);
    OCMStub([(NSLocale *)mockNSLocale objectForKey:OCMOCK_ANY]).andReturn(@"USD");
    __block PWRequest *postEventRequest = nil;
    self.mockRequestManager.onSendRequest = ^(PWRequest *request) {
        if ([request isKindOfClass:[PWPostEventRequest class]]) {
            postEventRequest = request;
        }
    };
    
    [(PWPurchaseManager *)self.purchaseManager sendSKPayments:transactions];
    
    OCMVerifyAll(mockSKPayment);
    NSDictionary *requestDictionary = postEventRequest.requestDictionary;
    NSDictionary *attributes = requestDictionary[@"attributes"];
    XCTAssertEqualObjects(requestDictionary[@"application"], [PWPreferences preferences].appCode);
    XCTAssertEqualObjects(requestDictionary[@"device_type"], @(DEVICE_TYPE));
    XCTAssertEqualObjects(requestDictionary[@"hwid"], [PWPreferences preferences].hwid);
    XCTAssertEqualObjects(requestDictionary[@"userId"], [PWPreferences preferences].userId);
    XCTAssertEqualObjects(requestDictionary[@"v"], PUSHWOOSH_VERSION);
    XCTAssertEqualObjects(attributes[@"__currency"], @"USD");
    XCTAssertEqualObjects([NSDecimalNumber decimalNumberWithString:@"123.21"], @123.21);
    XCTAssertEqualObjects(attributes[@"productIdentifier"], @"_product_identifier_test_");
    XCTAssertEqualObjects(attributes[@"quantity"], @1);
    XCTAssertEqualObjects(attributes[@"transactionDate"], ([NSString stringWithFormat:@"%@", [NSDate date]]));
    assertThat(attributes, hasKey(@"__amount"));
    assertThat(attributes, hasKey(@"__currency"));
    assertThat(attributes, hasKey(@"productIdentifier"));
    assertThat(attributes, hasKey(@"quantity"));
    assertThat(attributes, hasKey(@"status"));
    XCTAssertTrue([attributes[@"__amount"] isKindOfClass:[NSNumber class]]);
    XCTAssertTrue([attributes[@"quantity"] isKindOfClass:[NSNumber class]]);
}

@end
