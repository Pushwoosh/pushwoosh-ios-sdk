//
//  PWRequestManagerMock.m
//  PushNotificationManager
//
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWRequestManagerMock.h"

@implementation PWRequestManagerMock

- (void)sendRequest:(PWRequest *)request completion:(void (^)(NSError *error))completion {
    if (self.onSendRequest) {
        self.onSendRequest(request);
    }
    
	if (completion) {
		if (self.failed) {
			NSError *error = [NSError errorWithDomain:@"pushwoosh" code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Testing error"}];
			completion(error);
		}
		else {
			[request parseResponse:self.response];
			completion(nil);
		}
    }

}


@end
