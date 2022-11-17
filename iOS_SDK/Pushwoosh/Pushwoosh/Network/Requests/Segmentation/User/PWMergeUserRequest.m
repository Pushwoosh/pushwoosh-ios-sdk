//
//  PWMergeUserRequest.m
//  PushNotificationManager
//
//  Created by User on 29/09/15.
//
//

#import "PWMergeUserRequest.h"

@interface PWMergeUserRequest ()

@end

@implementation PWMergeUserRequest

@synthesize srcUserId;
@synthesize dstUserId;
@synthesize doMerge;

- (NSString *)methodName {
	return @"mergeUser";
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = [self baseDictionary];
	dict[@"oldUserId"] = self.srcUserId;
	dict[@"newUserId"] = self.dstUserId;
	dict[@"merge"] = @(self.doMerge);

	NSInteger timezone = [[NSTimeZone localTimeZone] secondsFromGMT];
	NSInteger timestampUTC = [[NSDate date] timeIntervalSince1970];
	NSInteger timestampCurrent = timestampUTC + timezone;
	dict[@"ts"] = @(timestampCurrent);

	return dict;
}

@end
