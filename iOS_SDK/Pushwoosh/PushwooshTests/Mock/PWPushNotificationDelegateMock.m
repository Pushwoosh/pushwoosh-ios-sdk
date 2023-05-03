//
//  PWPushNotificationDelegateMock.m
//  PushNotificationManager
//
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWPushNotificationDelegateMock.h"

#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

@implementation PWPushNotificationDelegateMock

- (instancetype)init {
	self = [super init];
	if (self) {
		_mock = mockProtocol(@protocol(PushNotificationDelegate));
	}
	return self;
}

- (void)onDidRegisterForRemoteNotificationsWithDeviceToken:(NSString *)token {
	[_mock onDidRegisterForRemoteNotificationsWithDeviceToken:token];
}

- (void)onDidFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
	[_mock onDidFailToRegisterForRemoteNotificationsWithError:error];
}

- (void)onPushReceived:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart {
	[_mock onPushReceived:pushManager withNotification:pushNotification onStart:onStart];
}

- (void)onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart {
	[_mock onPushAccepted:pushManager withNotification:pushNotification onStart:onStart];
}

- (void)onTagsReceived:(NSDictionary *)tags {
	[_mock onTagsReceived:tags];
}

- (void)onTagsFailedToReceive:(NSError *)error {
	[_mock onTagsFailedToReceive:error];
}

- (void)onInAppClosed:(NSString *)code {
	[_mock onInAppClosed:code];
}

- (void)onInAppDisplayed:(NSString *)code {
	[_mock onInAppDisplayed:code];
}

@end
