//
//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PWGetResourcesRequest.h"
#import "PWResource.h"

@interface PWGetResourcesRequest () 

@property (nonatomic, copy) NSDictionary *resources;

@end

@implementation PWGetResourcesRequest

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = self.baseDictionary;
	dict[@"language"] = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
	return dict;
}

- (void)parseResponse:(NSDictionary *)response {
	NSArray *inApps = [response pw_arrayForKey:@"inApps"];

	NSMutableDictionary *results = [NSMutableDictionary dictionary];
	for (NSDictionary *dict in inApps) {
		if ([dict isKindOfClass:[NSDictionary class]]) {
			PWResource *resource = [[PWResource alloc] initWithDictionary:dict];
			if (resource) {
				results[resource.code] = resource;
			}
		}
	}
	_resources = results;
}

- (NSString *)methodName {
	return @"getInApps";
}

@end
