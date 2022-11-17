
#import "PushNotificationManager.h"

@interface PushNotificationManager (Mock)

/**
 * Force PushNotificationManager class to use stub methods
 */
+ (void)setMock:(BOOL)mock;


/**
 * Set proxy handler for PushManager methods
 */
+ (void)setProxy:(id)proxy;

@end
