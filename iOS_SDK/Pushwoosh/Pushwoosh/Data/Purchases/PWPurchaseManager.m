//
//  PWPurchaseManager.m
//  PushNotificationManager
//
//	Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import "PWPurchaseManager.h"
#import "PWRequestManager.h"
#import "PWNetworkModule.h"
#import "PWSendPurchaseRequest.h"
#import "PWPostEventRequest.h"

@interface PWPurchaseManager () <SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (nonatomic, strong) NSMutableArray *transactionsArray;
@property (nonatomic, strong) NSMutableDictionary *productArray;  //productid => SKProduct mapping

// @Inject
@property (nonatomic, strong) PWRequestManager *requestManager;

@end

@implementation PWPurchaseManager

- (void)dealloc {
	NSNumber *noTrackIAP = @YES;  //[[NSBundle mainBundle] objectForInfoDictionaryKey:@"Pushwoosh_NO_TRACK_IAP"];
	if (!noTrackIAP || ![noTrackIAP boolValue]) {
		[[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
	}
}

- (instancetype)init {
	if (self = [super init]) {
		[[PWNetworkModule module] inject:self];
		
		NSNumber *noTrackIAP = @YES;  //[[NSBundle mainBundle] objectForInfoDictionaryKey:@"Pushwoosh_NO_TRACK_IAP"];
		if (!noTrackIAP || ![noTrackIAP boolValue]) {
			// Start observing purchase transactions
			[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
		}
	}
	return self;
}

- (void)sendSKPaymentTransactions:(NSArray *)transactions {
	NSMutableArray *productIdentifiers = [NSMutableArray new];
	self.transactionsArray = [NSMutableArray new];

	for (SKPaymentTransaction *transaction in transactions) {
		//we look only for purchased transactions, not restored, not failed
		if (transaction.transactionState == SKPaymentTransactionStatePurchased) {
			//add transaction to the queue
			BOOL addProductId = YES;
			for (NSString *pi in productIdentifiers) {
				if ([pi isEqualToString:transaction.payment.productIdentifier]) {
					addProductId = NO;
					break;
				}
			}

			//we'll need product identifiers to get the price
			if (addProductId)
				[productIdentifiers addObject:transaction.payment.productIdentifier];

			[self.transactionsArray addObject:transaction];
		}
	}

	if (productIdentifiers.count == 0)
		return;

	//request price for product identifiers
	SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
	productsRequest.delegate = self;
	[productsRequest start];
}

//something changes in the transaction queue
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
	[self sendSKPaymentTransactions:transactions];
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
	//map the SKProduct for product identifiers
	self.productArray = [NSMutableDictionary new];

	for (SKProduct *product in response.products) {
		(self.productArray)[product.productIdentifier] = product;
	}

	//now we can process transactions
	[self sendSKPayments:self.transactionsArray];
}

#pragma mark -

- (void)sendPurchase:(NSString *)productIdentifier withPrice:(NSDecimalNumber *)price currencyCode:(NSString *)currencyCode andDate:(NSDate *)date {
	if (!price)
		price = [NSDecimalNumber zero];
    
	if (!currencyCode)
		currencyCode = @"USD";
    
    if (!productIdentifier)
        productIdentifier = @"unknowProduct";
        
    if (!date)
        date = [NSDate date];
    
    PWPostEventRequest *postEventRequest = [PWPostEventRequest new];
    
    postEventRequest.event = @"PW_InAppPurchase";
    postEventRequest.attributes = @{@"productIdentifier": [self checkStringOrEempty:productIdentifier],
                                    @"quantity": @1,
                                    @"__amount": price,
                                    @"transactionDate": [NSString stringWithFormat:@"%@", date],
                                    @"__currency": currencyCode,
                                    @"status": @"success"
    };
    
    if (![postEventRequest.attributes isKindOfClass:[NSDictionary class]]) {
        PWLogError(@"Uncorrect attributes format");
        return;
    }
    
    [_requestManager sendRequest:postEventRequest completion:^(NSError *error) {
        if (error) {
            PWLogError(@"sendPurchase failed");
        }
    }];
}

- (NSString *)convertDateToString:(NSDate *)date {
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd"];
    return [dateFormat stringFromDate:date];
}

- (void)sendSKPayments:(NSArray *)transactions {
	for (SKPaymentTransaction *transaction in transactions) {
		NSString *productIdentifier = transaction.payment.productIdentifier;
        if (!productIdentifier)
            productIdentifier = @"unknowProduct";
        
		SKProduct *product = (self.productArray)[productIdentifier];
		if (!product) {
			PWLogWarn(@"Could not find product for transaction: %@", productIdentifier);
			continue;
		}

		NSDecimalNumber *price = product.price;
		if (!price)
			price = [NSDecimalNumber zero];

		NSString *currencyCode = [product.priceLocale objectForKey:NSLocaleCurrencyCode];
		if (!currencyCode)
			currencyCode = @"USD";
        
        NSString *status = @"";
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                status = @"success";
                break;
            case SKPaymentTransactionStateFailed:
                status = @"failed";
                break;
            case SKPaymentTransactionStateRestored:
                status = @"restored";
                break;
            default:
                status = @"unknow";
                break;
        }
        
        NSDate *date = [NSDate date];
        
        PWPostEventRequest *postEventRequest = [PWPostEventRequest new];
        
        postEventRequest.event = @"PW_InAppPurchase";
        postEventRequest.attributes = @{@"productIdentifier": [self checkStringOrEempty:productIdentifier],
                                        @"quantity": @1,
                                        @"__amount": price,
                                        @"transactionDate": [NSString stringWithFormat:@"%@", date],
                                        @"__currency": currencyCode,
                                        @"status": status
        };
        
        [_requestManager sendRequest:postEventRequest completion:^(NSError *error) {
            if (error) {
                PWLogError(@"sendPurchase failed");
            }
        }];
	}
}

- (NSString *)checkStringOrEempty:(NSString *)string {
    return string != nil ? string : @"";
}

@end
