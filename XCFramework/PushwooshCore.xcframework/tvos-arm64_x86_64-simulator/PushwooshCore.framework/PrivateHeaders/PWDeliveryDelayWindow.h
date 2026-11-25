//
//  PWDeliveryDelayWindow.h
//  Pushwoosh
//
//  Created by André Kis
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kPWDeliveryDelayPayloadKey;
FOUNDATION_EXPORT NSTimeInterval const kPWDeliveryDelayMaxWindow;

/// Parses the delivery-delay window out of a push payload and picks a random
/// point inside it, so the "delivered" event can be sent at an unpredictable
/// moment within the requested window instead of immediately on display.
@interface PWDeliveryDelayWindow : NSObject

/// Seconds of the requested window, or 0 when the push carries none.
+ (NSTimeInterval)windowFromUserInfo:(nullable NSDictionary *)userInfo;

/// Uniformly random point inside [0, window].
+ (NSTimeInterval)delayWithinWindow:(NSTimeInterval)window;

@end

NS_ASSUME_NONNULL_END
