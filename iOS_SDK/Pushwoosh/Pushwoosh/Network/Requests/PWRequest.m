//
//  PWRequest.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRequest.h"

#import "Constants.h"
#import "PushwooshFramework.h"
#import "PWUtils.h"

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

@implementation PWRequest

- (NSString *)uid {
    return [self methodName];
}

- (NSString *)methodName {
	return @"";
}

- (NSString *)requestIdentifier {
    return [NSString stringWithFormat:@"%ld", self.hash];
}

//Please note that all values will be processed as strings
- (NSDictionary *)requestDictionary {
	return nil;
}

- (NSMutableDictionary *)baseDictionary {
	NSMutableDictionary *dict = [NSMutableDictionary new];

	dict[@"userId"] = [PWSettings settings].userId;
	dict[@"application"] = [PWSettings settings].appCode;
    
    if (_usePreviousHWID && [PWUtils isValidHwid:[PWSettings settings].previosHWID]) {
        dict[@"hwid"] = [PWSettings settings].previosHWID;
    } else {
        dict[@"hwid"] = [PWSettings settings].hwid;
    }
	
	dict[@"v"] = PUSHWOOSH_VERSION;
	dict[@"device_type"] = @(DEVICE_TYPE);

	return dict;
}

- (void)parseResponse:(NSDictionary *)response {
}

@end
