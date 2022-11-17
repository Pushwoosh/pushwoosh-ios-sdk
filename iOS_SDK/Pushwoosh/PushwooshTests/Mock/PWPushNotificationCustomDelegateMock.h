//
//  PWPushNotificationDelegateMock.h
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 09/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PushNotificationManager.h"

#import <Foundation/Foundation.h>

// mockProtocol(@protocol(PushNotificationDelegate)) creates NSProxy without performSelector.. so we need NSObject wrapper
@interface PWPushNotificationCustomDelegateMock : NSObject<PushNotificationDelegate>

@property (nonatomic, readonly) id mock;

@end
