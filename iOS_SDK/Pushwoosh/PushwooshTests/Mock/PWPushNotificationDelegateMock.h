//
//  PWPushNotificationDelegateMock.h
//  PushNotificationManager
//
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PushNotificationManager.h"

#import <Foundation/Foundation.h>

// mockProtocol(@protocol(PushNotificationDelegate)) creates NSProxy without performSelector.. so we need NSObject wrapper
@interface PWPushNotificationDelegateMock : NSObject<PushNotificationDelegate>

@property (nonatomic, readonly) id mock;

@end
