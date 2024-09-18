//
//  PWTestPurchaseRuntime.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 28.12.2021.
//  Copyright © 2021 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <StoreKit/StoreKit.h>
#import <OCMock/OCMock.h>

#import "PWTestUtils.h"
#import "PWConfig.h"
#import "PWPurchaseRuntime.h"
#import "PushwooshFramework.h"
#import "PWPurchaseManager.h"

@interface PWPurchaseRuntime (UnitTests)

void dynamicUpdatedTransactions(id self, SEL _cmd, id queue, id transactions);

- (void)performSwizzlingForObserver:(id <SKPaymentTransactionObserver>)observer;

@end


@interface PWTestPurchaseRuntime : XCTestCase

@property (nonatomic) PWPurchaseRuntime *purchaseRuntime;

@end

@implementation PWTestPurchaseRuntime

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    [PWTestUtils tearDown];
}

@end
