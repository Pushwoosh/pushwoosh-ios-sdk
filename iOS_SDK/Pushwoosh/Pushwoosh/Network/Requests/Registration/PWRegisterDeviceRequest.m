//
//  PWRegisterDeviceRequest
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRegisterDeviceRequest.h"
#import "PushNotificationManager.h"
#import "PWUtils.h"
#import "PWPushRuntime.h"

#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"

#if TARGET_OS_IPHONE
#import "PWInteractivePush.h"
#endif

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

@interface PWRegisterDeviceRequest () 

@end

@implementation PWRegisterDeviceRequest

- (instancetype)init {
    if (self = [super init]) {
        self.cacheable = NO;
    }
    return self;
}

- (NSString *)methodName {
	return @"registerDevice";
}

- (NSArray *)buildSoundsList {
	NSMutableArray *listOfSounds = [[NSMutableArray alloc] init];

	NSString *bundleRoot = [[NSBundle mainBundle] bundlePath];
	NSError *err;
	NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundleRoot error:&err];
	for (NSString *filename in dirContents) {
		if ([filename hasSuffix:@".wav"] || [filename hasSuffix:@".caf"] || [filename hasSuffix:@".aif"]) {
			[listOfSounds addObject:filename];
		}
	}

	return listOfSounds;
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = [[super requestDictionary] mutableCopy];

	dict[@"push_token"] = _pushToken;
	dict[@"timezone"] = [PWUtils timezone];

	BOOL sandbox = ![PWUtils getAPSProductionStatus:NO];
	if (sandbox)
		dict[@"gateway"] = @"sandbox";
	else
		dict[@"gateway"] = @"production";

	NSArray *soundsList = [self buildSoundsList];
	dict[@"sounds"] = soundsList;

	return dict;
}

- (void)parseResponse:(NSDictionary *)response {
#if !TARGET_OS_OSX
    NSArray *iosCategories = response[@"iosCategories"];
    if (!iosCategories || ![iosCategories isKindOfClass:[NSArray class]] || [iosCategories count] == 0)
        return;
    
    [PWInteractivePush savePushwooshCategories:iosCategories];
    
    [PWInteractivePush getCategoriesWithCompletion:^(NSSet *categories) {
        [[[PWPlatformModule module] notificationManagerCompat] registerUserNotifications:categories completion:nil];
    }];
#endif
}

@end
