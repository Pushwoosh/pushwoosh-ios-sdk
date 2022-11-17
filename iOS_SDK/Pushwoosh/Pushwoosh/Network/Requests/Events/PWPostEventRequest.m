//
//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PWPostEventRequest.h"
#import "NSDate+PWDateUtils.h"

@interface PWPostEventRequest () 

@property (nonatomic, strong) NSString *resultCode;

@end

@implementation PWPostEventRequest

- (NSString *)methodName {
	return @"postEvent";
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dictionary = self.baseDictionary;

	dictionary[@"event"] = _event;

	if (_attributes) {
		dictionary[@"attributes"] = [self convertAttributes:_attributes];
	} else {
		dictionary[@"attributes"] = @{};
	}

	NSInteger timezone = [[NSTimeZone localTimeZone] secondsFromGMT];
	NSInteger timestampUTC = [[NSDate date] timeIntervalSince1970];
	NSInteger timestampCurrent = timestampUTC + timezone;

	dictionary[@"timestampUTC"] = @(timestampUTC);
	dictionary[@"timestampCurrent"] = @(timestampCurrent);

	return dictionary;
}

- (NSDictionary *)convertAttributes:(NSDictionary *)attributes {
	NSMutableDictionary *convertedAttributes = [attributes mutableCopy];
	for (id key in attributes) {
		convertedAttributes[key] = [self convertAttribute:convertedAttributes[key]];
	}

	return convertedAttributes;
}

- (NSObject *)convertAttribute:(NSObject *)attribute {
	if ([attribute isKindOfClass:[NSNull class]]) {
		return @"null";
	} else if ([attribute isKindOfClass:[NSArray class]]) {
		// convert [123, 456, "someString"] to ["123", "456", "someString"]
		NSMutableArray *convertedArray = [NSMutableArray new];
		for (id value in(NSArray *)attribute) {
			[convertedArray addObject:[self convertAttribute:value]];
		}
		return convertedArray;
	} else if ([attribute isKindOfClass:[NSNumber class]]) {
        if ([_event isEqualToString:@"PW_InAppPurchase"]) {
             return (NSDecimalNumber *)attribute;
        }
        // convert @YES to "1" and @NO to "0"
		NSNumber *numericAttribute = (NSNumber *)attribute;
		if (!strcmp([numericAttribute objCType], @encode(BOOL))) {
			BOOL value = [numericAttribute boolValue];
			return value ? @"1" : @"0";
		}
	} else if ([attribute isKindOfClass:[NSDate class]]) {
		NSDate *dateAttribute = (NSDate *)attribute;
        return dateAttribute.pw_formattedDate;
	}

	return [NSString stringWithFormat:@"%@", attribute];
}

- (void)parseResponse:(NSDictionary *)response {
	_resultCode = [response pw_stringForKey:@"code"];
    NSNumber *required = [response pw_numberForKey:@"required"];
    _required = required.boolValue;
}

@end
