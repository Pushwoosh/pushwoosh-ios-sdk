//
//  PWRegisterTestDeviceRequest
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRegisterTestDeviceRequest.h"

@interface PWRegisterDeviceRequest () 

@end

@implementation PWRegisterTestDeviceRequest

- (NSString *)methodName {
	return @"createTestDevice";
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = [[super requestDictionary] mutableCopy];

	dict[@"name"] = _name;
	dict[@"description"] = _desc;

	return dict;
}

- (void)parseResponse:(NSDictionary *)response {
}

@end
