//
//  PWSetTagsRequest.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWSetTagsRequest.h"
#import "NSDate+PWDateUtils.h"

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

@interface PWSetTagsRequest () 

@end

@implementation PWSetTagsRequest
@synthesize tags;

- (NSString *)methodName {
	return @"setTags";
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = [self baseDictionary];
	NSMutableDictionary *mutableTags = [tags mutableCopy];

	for (NSString *key in [mutableTags allKeys]) {
		NSString *valueString = @"";
		NSObject *value = mutableTags[key];

		if ([value isKindOfClass:[NSString class]]) {
			valueString = (NSString *)value;

			if ([valueString hasPrefix:@"#pwinc#"]) {
				NSString *noPrefixString = [valueString substringFromIndex:7];
				NSNumber *valueNumber = @([noPrefixString doubleValue]);

				NSMutableDictionary *opTag = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"increment", @"operation", valueNumber, @"value", nil];
				mutableTags[key] = opTag;
			}
        } else if ([value isKindOfClass:[NSDate class]]) {
            NSDate *dateTag = (NSDate *)value;
            mutableTags[key] = dateTag.pw_formattedDate;
        }
	}

	dict[@"tags"] = mutableTags;
	return dict;
}

@end
