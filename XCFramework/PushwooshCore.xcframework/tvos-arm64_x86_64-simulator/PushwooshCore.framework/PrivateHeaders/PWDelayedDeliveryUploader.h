//
//  PWDelayedDeliveryUploader.h
//  PushwooshCore
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_IOS

/// Hands a ready request to a background URLSession of the Notification Service Extension: the system
/// sends it no earlier than the given delay, also after the extension is gone. A failed attempt
/// (no response, HTTP 408, 429, 500, 502, 503, 504) is sent again 10 s × attempt later, five attempts in all,
/// by whichever process the system hands the outcome to: the extension while it runs, otherwise the app.
@interface PWDelayedDeliveryUploader : NSObject

/// Stages the body in the App Group container and schedules its upload `delay` seconds from now;
/// bodies older than a day left there by earlier calls are removed.
/// NO when the container of `appGroupsName` is unavailable or no task was scheduled.
+ (BOOL)scheduleRequest:(NSURLRequest *)urlRequest afterDelay:(NSTimeInterval)delay appGroupsName:(nullable NSString *)appGroupsName;

/// The app side of `application:handleEventsForBackgroundURLSession:completionHandler:`.
/// YES when `identifier` names a delivery session: its events are taken by the SDK and `completionHandler`
/// is called on the main queue once they are handled. NO leaves the call to the app.
+ (BOOL)handleEventsForBackgroundURLSession:(NSString *)identifier
                              appGroupsName:(nullable NSString *)appGroupsName
                          completionHandler:(void (^)(void))completionHandler;

@end

#endif

NS_ASSUME_NONNULL_END
