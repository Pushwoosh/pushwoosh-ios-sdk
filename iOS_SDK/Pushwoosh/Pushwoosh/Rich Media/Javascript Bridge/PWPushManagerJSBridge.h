#if TARGET_OS_IOS
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

API_DEPRECATED("No longer supported. Please use PWPushwooshJSBridge", ios(8.0, 12.0))

@interface PWPushManagerJSBridge : NSObject

- (id)initWithClient:(PWWebClient *)webClient;

@property (nonatomic, weak) id<PWPushManagerJSBridgeDelegate> delegate;

@end
#endif
