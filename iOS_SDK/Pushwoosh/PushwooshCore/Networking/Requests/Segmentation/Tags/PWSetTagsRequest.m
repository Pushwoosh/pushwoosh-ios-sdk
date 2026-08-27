//
//  PWSetTagsRequest.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWSetTagsRequest.h"
#import "NSDate+PWDateUtils.h"

@interface PWSetTagsRequest ()

@end

@implementation PWSetTagsRequest
@synthesize tags;

- (NSString *)methodName {
	return @"setTags";
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = [self baseDictionary];
	NSDictionary *tagsSnapshot = [tags copy];
	NSMutableDictionary *sanitizedTags = [NSMutableDictionary dictionary];

	for (NSString *key in [tagsSnapshot allKeys]) {
		if (![key isKindOfClass:[NSString class]]) {
			continue;
		}
		NSObject *value = tagsSnapshot[key];

		if ([value isKindOfClass:[NSString class]]) {
			NSString *valueString = (NSString *)value;

			if ([valueString hasPrefix:@"#pwinc#"]) {
				NSString *noPrefixString = [valueString substringFromIndex:7];
				NSNumber *valueNumber = @([noPrefixString doubleValue]);

				sanitizedTags[key] = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"increment", @"operation", valueNumber, @"value", nil];
			} else {
				sanitizedTags[key] = valueString;
			}
		} else if ([value isKindOfClass:[NSDate class]]) {
			sanitizedTags[key] = ((NSDate *)value).pw_formattedDate;
		} else if ([value isKindOfClass:[NSNumber class]]) {
			double number = [(NSNumber *)value doubleValue];
			if (!isnan(number) && !isinf(number)) {
				sanitizedTags[key] = value;
			}
		} else if ([NSJSONSerialization isValidJSONObject:@{key: value}]) {
			sanitizedTags[key] = value;
		}
	}

	dict[@"tags"] = sanitizedTags;
	return dict;
}

@end
