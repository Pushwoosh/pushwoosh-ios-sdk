
#import "PWPushManagerJSBridge.h"
#import "PushNotificationManager.h"
#import "PWInAppManager.h"
#import "PWPushRuntime.h"
#import "Pushwoosh+Internal.h"
#import "PWPushNotificationsManager.h"
#import "PWWebClient.h"
#import "PWUtils.h"

@interface PWPushManagerJSBridge ()

@property (nonatomic, weak) PWWebClient *webClient;

@end

@implementation PWPushManagerJSBridge

- (id)initWithClient:(PWWebClient*)webClient {
    self = [super init];
    if (self) {
        self.webClient = webClient;
    }
    return self;
}


+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
	return NO;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
	return NO;
}

+ (NSString *)webScriptNameForSelector:(SEL)sel {
	// Naming rules can be found at: https://developer.apple.com/library/mac/documentation/Cocoa/Reference/WebKit/Protocols/WebScripting_Protocol/Reference/Reference.html
    if (sel == @selector(postEvent:)) {
        return @"postEvent";
    }
    if (sel == @selector(sendTags:)) {
        return @"sendTags";
    }
    if (sel == @selector(closeInApp)) {
        return @"closeInApp";
    }
    if (sel == @selector(registerForPushNotifications)) {
        return @"registerForPushNotifications";
    }

	return nil;
}

/**
 * JavaScript proxy for [pushManager postEvent: withAttributes:] method
 *
 * js example:
 *		var today = new Date();
 *		var eventAttributes = {
 *			"TestAttributeString" : "testString",
 *			"TestAttributeInt" : 42,
 *			"TestAttributeList" : [ 123, 456, "someString" ],
 *			"TestAttributeBool" : true,
 *			"TestAttributeNull" : null,
 *			"TestAttributeDaysAgo" : 7,
 *			"TestAttributeDate" : today
 *		};
 *		window.successCallback = function () {
 *			console.log("Post event success");
 *		};
 *		window.errorCallback = function (message) {
 *			console.log("Post event failed: ", message);
 *			alert("Post event failed: " + message);
 *		};
 *
 *
 *		pushManager.postEvent(JSON.stringify({
 *			"event" : "testEvent",
 *			"attributes" : eventAttributes,
 *			"success" : "successCallback",	// optional
 *			"error" : "errorCallback"		// optional
 *		}));
 */
- (void)postEvent:(NSString *)blob {
	NSError *jsonError;
	NSData *objectData = [blob dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *blobDict = [NSJSONSerialization JSONObjectWithData:objectData
															 options:NSJSONReadingMutableContainers
															   error:&jsonError];

	if (jsonError) {
		PWLogError(@"Invalid postEvent argument %@", [jsonError localizedDescription]);
		return;
	}

	NSString *event = blobDict[@"event"];
	NSDictionary *attributesDict = blobDict[@"attributes"];
	NSString *successCallback = blobDict[@"success"];
	NSString *errorCallback = blobDict[@"error"];

	[[PWInAppManager sharedManager] postEvent:event withAttributes:attributesDict completion:^(NSError *error) {
		if (!error) {
			if (successCallback) {
				NSString *javaScriptRequest = [NSString stringWithFormat:@"%@()", successCallback, nil];

                /**
                 Starting with iOS 14, we use WKContentWorld to run injected JavaScript in a secure sandboxed environment,
                 isolating it from untrusted web JavaScript. More details: https://developer.apple.com/documentation/webkit/wkcontentworld
                 */
                if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"14.0"]) {
                    WKContentWorld* sandbox = [WKContentWorld pageWorld];
                    [self.webClient.webView evaluateJavaScript:javaScriptRequest
                                                       inFrame:nil
                                                inContentWorld:sandbox
                                             completionHandler:nil];
                } else {
                    [self.webClient.webView evaluateJavaScript:javaScriptRequest completionHandler:nil];
                }

			}
		} else {
			if (errorCallback) {
				NSString *javaScriptRequest = [NSString stringWithFormat:@"%@('%@')", errorCallback, error.localizedDescription, nil];
                /**
                 Starting with iOS 14, we use WKContentWorld to run injected JavaScript in a secure sandboxed environment,
                 isolating it from untrusted web JavaScript. More details: https://developer.apple.com/documentation/webkit/wkcontentworld
                 */
                if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"14.0"]) {
                    WKContentWorld* sandbox = [WKContentWorld pageWorld];
                    [self.webClient.webView evaluateJavaScript:javaScriptRequest
                                                       inFrame:nil
                                                inContentWorld:sandbox
                                             completionHandler:nil];
                } else {
                    [self.webClient.webView evaluateJavaScript:javaScriptRequest completionHandler:nil];
                }

			}
		}
	}];
}

/**
 * JavaScript proxy for [pushManager registerForPushNotifications] method
 *
 * js example:
 *	pushManager.registerForPushNotifications();
 */

- (void)registerForPushNotifications {
    [[Pushwoosh sharedInstance].pushNotificationManager registerForPushNotificationsWithCompletion:nil];
}

/**
 * JavaScript proxy for [pushManager setTags:] method
 *
 * js example:
 *	var tags = {
 *		"IntTag" : 42,
 *		"BoolTag" : true,
 *		"StringTag" : "testString",
 *		"ListTag" : [ "string1", "string2" ]
 *	};
 *	pushManager.sendTags(JSON.stringify(tags));
 */
- (void)sendTags:(NSString *)serializedTags {
	NSError *jsonError;
	NSData *objectData = [serializedTags dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *tags = [NSJSONSerialization JSONObjectWithData:objectData
														 options:NSJSONReadingMutableContainers
														   error:&jsonError];

	if (jsonError) {
		PWLogError(@"Invalid postEvent argument %@", [jsonError localizedDescription]);
		return;
	}

	[[PushNotificationManager pushManager] setTags:tags];
}

/**
 * helper method to print javascipt logs to iOS console
 */
- (void)log:(NSString*)str {
	PWLogDebug(str);
}

/**
 * Close current In-App
 */
- (void)closeInApp {
	[self.delegate onMessageClose];
}

@end
