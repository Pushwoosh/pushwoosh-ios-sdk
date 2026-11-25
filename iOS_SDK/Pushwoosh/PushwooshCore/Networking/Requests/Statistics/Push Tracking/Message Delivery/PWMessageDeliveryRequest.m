//
//  PWMessageDeliveryRequest.m
//  Pushwoosh
//
//  Created by Fectum on 25/06/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWMessageDeliveryRequest.h"
#import "PWMessageDeliveryRequest+Internal.h"

@implementation PWMessageDeliveryRequest

- (instancetype)init {
    if (self = [super init]) {
        self.cacheable = YES;
    }
    return self;
}

- (NSString *)methodName {
    return @"messageDeliveryEvent";
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [super requestDictionary].mutableCopy;
    NSString *metadata = self.pushDict[@"md"];

    if (metadata != nil) {
        dict[@"metaData"] = metadata;
    }

    if (self.receivedDate != nil) {
        dict[@"receivedAt"] = [self receivedAtString];
    }

    return dict;
}

- (NSString *)receivedAtString {
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDate *wholeSeconds = [NSDate dateWithTimeIntervalSince1970:floor(self.receivedDate.timeIntervalSince1970)];
    return [formatter stringFromDate:wholeSeconds];
}

@end
