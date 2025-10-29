//
//  PWSendPurchaseRequest
//  Pushwoosh SDK
//  (c) Pushwoosh 2014
//

#import "PWSendPurchaseRequest.h"

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

@implementation PWSendPurchaseRequest

- (instancetype)init {
    if (self = [super init]) {
        self.cacheable = NO;
    }
    return self;
}

- (NSString *)methodName {
	return @"setPurchase";
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = [self baseDictionary];

	dict[@"productIdentifier"] = _productIdentifier;
	dict[@"quantity"] = @(_quantity);

	if (_transactionDate != nil)
		dict[@"transactionDate"] = [NSNumber numberWithInt:_transactionDate.timeIntervalSince1970];

	dict[@"price"] = _price;
	dict[@"currency"] = _currencyCode;

	return dict;
}

@end
