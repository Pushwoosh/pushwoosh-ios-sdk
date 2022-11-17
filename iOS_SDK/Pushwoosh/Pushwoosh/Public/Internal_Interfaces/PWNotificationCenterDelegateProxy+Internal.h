//
//  PWNotificationCenterDelegateProxy+Internal.h
//  Pushwoosh
//
//  Created by Fectum on 28.02.2020.
//  Copyright © 2020 Pushwoosh. All rights reserved.
//

@class PWPushNotificationsManager;

NS_ASSUME_NONNULL_BEGIN

@interface PWNotificationCenterDelegateProxy ()

- (instancetype)initWithNotificationManager:(PWPushNotificationsManager *)manager;

@end

NS_ASSUME_NONNULL_END
