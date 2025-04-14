//
//  PWPurchaseManager.h
//  PushNotificationManager
//
//	Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import <PushwooshCore/PushwooshLog.h>

@import Foundation;
@import StoreKit;

@interface PWPurchaseManager : NSObject

- (void)sendSKPaymentTransactions:(NSArray *)transactions;

- (void)sendPurchase:(NSString *)productIdentifier withPrice:(NSDecimalNumber *)price currencyCode:(NSString *)currencyCode andDate:(NSDate *)date;

@end
