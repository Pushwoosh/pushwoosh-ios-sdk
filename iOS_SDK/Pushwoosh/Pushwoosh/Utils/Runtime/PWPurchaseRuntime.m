//
//  PWPurchaseRuntime.m
//  Pushwoosh
//
//  Created by Kiselev Andrey on 27.12.2021.
//  Copyright © 2021 Pushwoosh. All rights reserved.
//

#import "PWPurchaseRuntime.h"
#import <objc/runtime.h>
#import <objc/message.h>

#import <StoreKit/StoreKit.h>

#import "Pushwoosh+Internal.h"
#import "PWConfig.h"
#import "PWPreferences.h"
#import "PWInteractivePush.h"
#import "PWUtils.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

static IMP pw_original_paymentQueue_updatedTransactions_Imp;
static IMP pw_original_addTransactionObserver_Imp;

@implementation SKPaymentQueue (Pushwoosh)

- (void)performSwizzlingForObserver:(id <SKPaymentTransactionObserver>)observer {
    static BOOL swizzleDone = NO;

    //do not swizzle twice
    if (swizzleDone || observer == nil)
        return;

    swizzleDone = YES;
    
    [self swizzle_paymentQueueUpdatedTransactions:observer];
}

- (void)swizzle_paymentQueueUpdatedTransactions:(id <SKPaymentTransactionObserver>)observer {
    Method originalMethod = class_getInstanceMethod([observer class], @selector(paymentQueue:updatedTransactions:));
    pw_original_paymentQueue_updatedTransactions_Imp = method_setImplementation(originalMethod, (IMP)_replacement_paymentQueueUpdatedTransactions);
}

void _replacement_paymentQueueUpdatedTransactions(SKPaymentQueue * self, SEL _cmd, SKPaymentQueue * queue, NSArray<SKPaymentTransaction *> * transactions) {
    ((void(*)(id, SEL, SKPaymentQueue *, NSArray<SKPaymentTransaction *> *))pw_original_paymentQueue_updatedTransactions_Imp)(self, _cmd, queue, transactions);
    
    [[Pushwoosh sharedInstance] sendSKPaymentTransactions:transactions];

}

+ (void)load {
    if (![[PWConfig config] sendPurchaseTrackingEnabled])
        return;
    
    static BOOL swizzleDone = NO;
    if (swizzleDone)
        return;
    swizzleDone = YES;
    
    Method originalMethod = class_getInstanceMethod([self class], @selector(addTransactionObserver:));
    pw_original_addTransactionObserver_Imp = method_setImplementation(originalMethod, (IMP)_replacement_addTransactionObserver);
}

void _replacement_addTransactionObserver(SKPaymentQueue * self, SEL _cmd, id <SKPaymentTransactionObserver> observer) {
    ((void(*)(id, SEL, id <SKPaymentTransactionObserver>))pw_original_addTransactionObserver_Imp)(self, _cmd, observer);
    
    [self performSwizzlingForObserver:observer];
}

@end
