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

- (NSArray *) buildSoundsList {
	NSMutableArray * listOfSounds = [[NSMutableArray alloc] init];
	
	NSString * bundleRoot = [[NSBundle mainBundle] bundlePath];
    NSError * err;
    NSArray * dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundleRoot error:&err];
    for (NSString * filename in dirContents) {
        if ([filename hasSuffix:@".wav"] || [filename hasSuffix:@".caf"] || [filename hasSuffix:@".aif"])
        {
            [listOfSounds addObject:filename];
        }
    }
	
	return listOfSounds;
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
	
	NSArray * soundsList = [self buildSoundsList];
	[dict setObject:soundsList forKey:@"sounds"];
	
	return dict;
}


@end
