//
//  PWInboxBridge.h
//  PushwooshCore
//
//  Created by André Kis on 20.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PWInboxBridge <NSObject>

+ (BOOL)isInboxPushNotification:(NSDictionary *)userInfo;
+ (void)addInboxMessageFromPushNotification:(NSDictionary *)userInfo;
+ (void)actionInboxMessageFromPushNotification:(NSDictionary *)userInfo;
+ (void)resetApplication;
+ (void)updateInboxForNewUserId:(void (^)(NSUInteger messagesCount))completion;

@end
