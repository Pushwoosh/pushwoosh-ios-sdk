//
//  PWInbox+Internal.h
//  Pushwoosh
//
//  Created by Victor Eysner on 18/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInbox.h"

@protocol PWInboxPayloadProtocol<NSObject>
@required

+ (BOOL)isInboxPushNotification:(NSDictionary *)userInfo;
+ (void)addInboxMessageFromPushNotification:(NSDictionary *)userInfo;
+ (void)actionInboxMessageFromPushNotification:(NSDictionary *)userInfo;
+ (void)resetApplication;

@end

@interface PWInbox (Internal)<PWInboxPayloadProtocol>

@end
