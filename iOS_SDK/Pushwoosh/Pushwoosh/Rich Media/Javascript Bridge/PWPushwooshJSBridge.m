//
//  PWPushwooshJSBridge.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2017
//

#import "PWPushwooshJSBridge.h"
#import "PWInAppManager.h"
#import "PushNotificationManager.h"
#import "Pushwoosh+Internal.h"
#import "PWPushNotificationsManager.h"
#import "PWGDPRManager.h"
#import "PWUtils.h"
#import "PWChannel.h"
#import "PWInAppPurchaseHelper.h"
#import "PWRequestManager.h"
#import "PWRichMediaActionRequest.h"
#import "PWNetworkModule.h"

#import "PWEasyJSWKDataFunction.h"

@interface PWPushwooshJSBridge()

@property (nonatomic, weak) PWWebClient *webClient;

// @Inject
@property (nonatomic, strong) PWRequestManager *requestManager;

@end

@implementation PWPushwooshJSBridge


- (id)initWithClient:(PWWebClient*)webClient {
	self = [super init];
	if (self) {
        [[PWNetworkModule module] inject:self];
        
		self.webClient = webClient;
	}
	return self;
}

/**
 * JavaScript proxy for [pushManager postEvent: withAttributes:] method
 *
 * js example:
 *		pushwoosh.postEvent({"eventName", {
 *				"TestAttributeString" : "testString",
 *				"TestAttributeInt" : 42,
 *				"TestAttributeList" : [ 123, 456, "someString" ],
 *				"TestAttributeBool" : true,
 *				"TestAttributeNull" : null,
 *				"TestAttributeDaysAgo" : 7,
 *				"TestAttributeDate" : new Date()
 *			},
 *			function() {
 *				console.log("Post event success");
 *			},
 *			function(error) {
 *				console.log("Post event failed: ", error);
 *			}
 *		}));
 */
- (void)postEvent:(NSString *)event :(NSString*)attributesStr :(PWEasyJSWKDataFunction*)successCallback :(PWEasyJSWKDataFunction*)errorCallback {
	NSError *jsonError;
	NSData *attributesData = [attributesStr dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *attributes = [NSJSONSerialization JSONObjectWithData:attributesData
															 options:NSJSONReadingMutableContainers
															   error:&jsonError];
	
	if (jsonError) {
		PWLogError(@"Invalid postEvent argument %@", [jsonError description]);
		[errorCallback executeWithParam:[jsonError description]];
		return;
	}
	
	[[PWInAppManager sharedManager] postEvent:event withAttributes:attributes completion:^(NSError *error) {
		if (!error) {
			[successCallback execute];
		} else {
			[errorCallback executeWithParam:[error description]];
		}
	}];
}

- (void)richMediaAction:(NSString *)inAppCode
                       :(NSString *)richMediaCode
                       :(NSNumber *)actionType
                       :(NSString *)actionAttributes
                       :(PWEasyJSWKDataFunction*)successCallback
                       :(PWEasyJSWKDataFunction*)errorCallback {
    PWRichMediaActionRequest *request = [[PWRichMediaActionRequest alloc] init];
    request.richMediaCode = richMediaCode;
    request.inAppCode = inAppCode;
    request.actionType = @([actionType integerValue]);
    request.messageHash = self.webClient.messageHash;
    request.actionAttributes = actionAttributes;
        
    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (!error) {
            [successCallback execute];
        } else {
            [errorCallback executeWithParam:[error description]];
        }
    }];
}

/**
 * JavaScript proxy for [pushManager setTags:] method
 *
 * js example:
 *	pushwoosh.sendTags({
 *		"IntTag" : 42,
 *		"BoolTag" : true,
 *		"StringTag" : "testString",
 *		"ListTag" : [ "string1", "string2" ]
 *	});
 */
- (void)sendTags:(NSString *)serializedTags {
	NSError *jsonError;
	NSData *objectData = [serializedTags dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *tags = [NSJSONSerialization JSONObjectWithData:objectData
														 options:NSJSONReadingMutableContainers
														   error:&jsonError];
	
	if (jsonError) {
		PWLogError(@"Invalid sendTags argument %@", [jsonError localizedDescription]);
		return;
	}
	
	[[PushNotificationManager pushManager] setTags:tags];
}

/**
 * JavaScript proxy for [pushManager getTags:] method
 *
 * js example:
 *	pushwoosh.getTags(function(tags) {
 *			console.log("tags: " + JSON.stringify(tags));
 *		}
 *		function(error) {
 *			console.log("failded to get tags: " + error);
 *		}
 *	);
 */
- (void)getTags:(PWEasyJSWKDataFunction*)successCallback :(PWEasyJSWKDataFunction*)errorCallback {
	[[PushNotificationManager pushManager] loadTags:^(NSDictionary *tags) {
		NSData *json = [NSJSONSerialization dataWithJSONObject:tags options:NSJSONWritingPrettyPrinted error:nil];
		NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
		
		[successCallback executeWithParam:jsonString];
	}error:^(NSError *error) {
		[errorCallback executeWithParam:[error description]];
	}];
}

- (NSString *)isCommunicationEnabled {
    return [PWGDPRManager sharedManager].isCommunicationEnabled ? @"true" : @"false";
}

- (void)setCommunicationEnabled:(NSString *)flag {
    BOOL properEnabled = [flag isEqualToString:@"true"];
    [[PWGDPRManager sharedManager] setCommunicationEnabled:properEnabled completion:^(NSError *error) {
        if (error) {
            [PWUtils showAlertWithTitle:@"Error" message:error.localizedDescription];
        }
    }];
}

- (void)removeAllDeviceData {
    [[PWGDPRManager sharedManager] removeAllDeviceDataWithCompletion:^(NSError *error) {
        if (error) {
            [PWUtils showAlertWithTitle:@"Error" message:error.localizedDescription];
        }
    }];
}

/**
 * JavaScript proxy for [pushManager registerForPushNotifications] method
 *
 * js example:
 *    pushwoosh.registerForPushNotifications();
 */
- (void)registerForPushNotifications {
    [[PushNotificationManager pushManager] registerForPushNotifications];
}

/**
 * JS proxy for open application settings
 * example: pushwoosh.openAppSettings();
 */
- (void)openAppSettings {
#if TARGET_OS_IOS
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
#endif
}

- (void)unregisterForPushNotifications:(PWEasyJSWKDataFunction *)callback {
    [[PushNotificationManager pushManager] unregisterForPushNotificationsWithCompletion:^(NSError *error) {
        if (error != nil) {
            [callback executeWithParam:[error description]];
        } else {
            [callback execute];
        }
    }];
}

- (void)isRegisteredForPushNotifications:(PWEasyJSWKDataFunction *)callback {
    [callback executeWithParam:[[PushNotificationManager pushManager] getPushToken] != nil ? @"true" : @"false"];
}

/**
 * helper method to print javascipt logs to iOS console
 */
- (void)log:(NSString*)str {
	PWLogDebug(str);
}

/**
 * Make App Store purchase from In-App
 */
- (void)makePurchaseWithIdentifier:(NSString*)identifier {
    if (identifier!=nil) {
        [[PWInAppPurchaseHelper sharedInstance] validateProductIdentifiers:[NSArray arrayWithObject:identifier]];
        [[PWInAppPurchaseHelper sharedInstance] payWithIdentifier:identifier];
    }
}


/**
 * Close current In-App
 */
- (void)closeInApp {
    NSNumber *closeActionType = @4;
    
	[self.webClient close];
    [self richMediaAction:self.webClient.inAppCode
                         :self.webClient.richMediaCode
                         :closeActionType
                         :nil
                         :nil
                         :nil];
}

@end
