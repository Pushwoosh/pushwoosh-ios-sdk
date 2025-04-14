
#import "PWMessageViewController.h"
#import <WebKit/WebKit.h>
#import <PushwooshCore/PushwooshLog.h>
#import "PWWebClient.h"

@protocol PWPushManagerJSBridgeDelegate <NSObject>

- (void)onMessageClose;

@end

/**
 * JavaScript interface object accessible from InApps JavaScript sources
 */

#if TARGET_OS_IOS

API_DEPRECATED("No longer supported. Please use PWPushwooshJSBridge", ios(8.0, 12.0))

#else

WEBKIT_CLASS_DEPRECATED_MAC(10_3, 10_14, "No longer supported. Please use PWPushwooshJSBridge")

#endif

@interface PWPushManagerJSBridge : NSObject

- (id)initWithClient:(PWWebClient *)webClient;

@property (nonatomic, weak) id<PWPushManagerJSBridgeDelegate> delegate;

@end
