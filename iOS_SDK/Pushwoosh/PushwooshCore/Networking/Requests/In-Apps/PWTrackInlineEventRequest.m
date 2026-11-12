//
//  PWTrackInlineEventRequest.m
//  PushwooshCore
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWTrackInlineEventRequest.h"

#if TARGET_OS_IOS

#import "PWGetInlineBannersRequest.h"
#import "PWRequest+Internal.h"

static const NSUInteger PWInlineEventQueueLimit = 100;

@interface PWTrackInlineEventRequest ()

@property (nonatomic, copy) NSDictionary<NSString *, id> *event;

@end

@implementation PWTrackInlineEventRequest

- (instancetype)initWithEvent:(NSDictionary<NSString *, id> *)event {
    self = [super init];
    if (self) {
        _event = [event copy];
        self.cacheable = YES;
    }
    return self;
}

- (NSString *)methodName {
    return @"trackInlineEvent";
}

- (BOOL)shouldWrapRequest {
    return NO;
}

- (BOOL)followsServerBaseUrl {
    return NO;
}

- (BOOL)pinsRetryHost {
    return YES;
}

- (BOOL)retryWaitsForNetwork {
    return YES;
}

- (NSUInteger)retryQueueLimit {
    return PWInlineEventQueueLimit;
}

- (BOOL)announcesRetryDelivery {
    return YES;
}

- (NSString *)baseUrl {
    return [PWGetInlineBannersRequest endpointForRequest:self];
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [self baseDictionary];
    [dict addEntriesFromDictionary:_event];
    return dict;
}

@end

#endif
