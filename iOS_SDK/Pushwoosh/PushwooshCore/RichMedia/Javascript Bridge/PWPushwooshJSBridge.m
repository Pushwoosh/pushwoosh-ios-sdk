//
//  PWPushwooshJSBridge.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2017
//

#if TARGET_OS_IOS
#import "PWPushwooshJSBridge.h"
#import "PWInAppManager.h"
#import <PushwooshCore/PWManagerBridge.h>
#import "PWPushNotificationsManager.h"
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
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:self
                           message:[NSString stringWithFormat:@"Invalid postEvent argument %@", [jsonError description]]];
		[errorCallback executeWithParam:[jsonError description]];
		return;
	}
	
	[[[PWManagerBridge shared] inAppManager] postEvent:event withAttributes:attributes completion:^(NSError *error) {
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
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:self
                           message:[NSString stringWithFormat:@"Invalid sendTags argument %@", [jsonError localizedDescription]]];
		return;
	}
	
	[[PWManagerBridge shared] setTags:tags];
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
	[[PWManagerBridge shared] loadTags:^(NSDictionary *tags) {
		NSData *json = [NSJSONSerialization dataWithJSONObject:tags options:NSJSONWritingPrettyPrinted error:nil];
		NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
		
		[successCallback executeWithParam:jsonString];
	}error:^(NSError *error) {
		[errorCallback executeWithParam:[error description]];
	}];
}

/**
 * JavaScript proxy for [pushManager registerForPushNotifications] method
 *
 * js example:
 *    pushwoosh.registerForPushNotifications();
 */
- (void)registerForPushNotifications {
    [[PWManagerBridge shared] registerForPushNotifications];
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
    [[PWManagerBridge shared] unregisterForPushNotificationsWithCompletion:^(NSError *error) {
        if (error != nil) {
            [callback executeWithParam:[error description]];
        } else {
            [callback execute];
        }
    }];
}

- (void)isRegisteredForPushNotifications:(PWEasyJSWKDataFunction *)callback {
    [callback executeWithParam:[[PWManagerBridge shared] getPushToken] != nil ? @"true" : @"false"];
}

/**
 * helper method to print javascipt logs to iOS console
 */
- (void)log:(NSString*)str {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:str];
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
 * JavaScript proxy for [pushManager setEmail:] method
 *
 * js example:
 *    pushwoosh.setEmail("user@example.com");
 */
- (void)setEmail:(NSString *)email {
    [[PWManagerBridge shared] setEmail:email];
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
#endif
