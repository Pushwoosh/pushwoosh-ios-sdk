//
//  PWSendPurchaseRequest
//  Pushwoosh SDK
//  (c) Pushwoosh 2014
//

#import "PWRequest.h"

@interface PWSendPurchaseRequest : PWRequest

@property (nonatomic, copy) NSString *productIdentifier;
@property (nonatomic) NSInteger quantity;
@property (nonatomic, retain) NSDate *transactionDate;
@property (nonatomic, retain) NSDecimalNumber *price;
@property (nonatomic, copy) NSString *currencyCode;

@end
