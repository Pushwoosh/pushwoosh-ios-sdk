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

typedef NS_ENUM(NSInteger, PWPlatform) {
    iOS = 1,
    SMS = 18,
    Whatsapp = 21
};

@interface PWRegisterDeviceRequest ()

@end

@implementation PWRegisterDeviceRequest

- (instancetype)init {
    if (self = [super init]) {
        self.cacheable = YES;
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

    dict[@"push_token"] = _token;
    dict[@"device_type"] = @(_platform);
    dict[@"timezone"] = [PWUtils timezone];

    switch (_platform) {
        case SMS:
            dict[@"hwid"] = _token;
            break;
            
        case Whatsapp: {
            NSString *whatsappToken = [@"whatsapp:" stringByAppendingString:_token];
            dict[@"hwid"] = whatsappToken;
            dict[@"push_token"] = whatsappToken;
            break;
        }
        
        case iOS: {
            BOOL sandbox = ![PWUtils getAPSProductionStatus:NO];
            dict[@"gateway"] = sandbox ? @"sandbox" : @"production";
            
            NSArray *soundsList = [self buildSoundsList];
            dict[@"sounds"] = soundsList;
            break;
        }
            
        default:
            break;
    }

    if (_customTags) {
        dict[@"tags"] = _customTags;
    }

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
