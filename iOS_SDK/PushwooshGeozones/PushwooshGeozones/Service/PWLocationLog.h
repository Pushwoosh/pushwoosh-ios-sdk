//
//  PWLocationLog.h
//  Pushwoosh
//
//  Created by Victor Eysner on 04/09/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CLLocation;
@interface PWLocationLog : NSObject

+ (void)log:(NSString *)message withTracker:(NSObject *)tracker;
+ (void)logDebug:(NSString *)message withTracker:(NSObject *)tracker;
+ (void)reportLocation:(CLLocation *)location withMessage:(NSString *)message tracker:(NSObject *)tracker;
+ (void)sendNotificationLocation:(CLLocation *)location withMessage:(NSString *)message tracker:(NSObject *)tracker;

@end
