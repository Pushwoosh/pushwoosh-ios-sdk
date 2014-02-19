//
//  PWRegisterDeviceRequest
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRegisterDeviceRequest.h"
#import "PushNotificationManager.h"

#if ! __has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

@implementation PWRegisterDeviceRequest

- (NSString *) methodName {
	return @"registerDevice";
}

- (NSDictionary *) requestDictionary {
	NSMutableDictionary *dict = [self baseDictionary];
	
	[dict setObject:[NSNumber numberWithInt:1] forKey:@"device_type"];
	[dict setObject:_pushToken forKey:@"push_token"];
	[dict setObject:_language forKey:@"language"];
	[dict setObject:_timeZone forKey:@"timezone"];
    
    if (_appVersion)
        [dict setObject:_appVersion forKey:@"app_version"];
    
    if (_isJailBroken)
         [dict setObject:@(YES) forKey:@"black"];
    
	BOOL sandbox = ![PushNotificationManager getAPSProductionStatus];
	if(sandbox)
		[dict setObject:@"sandbox" forKey:@"gateway"];
	else
		[dict setObject:@"production" forKey:@"gateway"];

	NSString * package = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
	[dict setObject:package forKey:@"package"];
	
	return dict;
}


@end
