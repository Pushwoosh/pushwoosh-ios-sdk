//
//  PWPushNotificationDelegateMock.m
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 09/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWPushNotificationCustomDelegateMock.h"

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

@implementation PWPushNotificationCustomDelegateMock

- (instancetype)init {
    self = [super init];
    if (self) {
        _mock = mockProtocol(@protocol(PushNotificationDelegate));
    }
    return self;
}

- (void)onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart {
    [_mock onPushAccepted:pushManager withNotification:pushNotification onStart:onStart];
}

@end
