//
//  PWUnregisterDeviceRequest.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2013
//

#import "PWUnregisterDeviceRequest.h"

@interface PWUnregisterDeviceRequest () 

@end

@implementation PWUnregisterDeviceRequest

- (NSString *)methodName {
	return @"unregisterDevice";
}

- (NSDictionary *)requestDictionary {
	return [self baseDictionary];
}

@end
