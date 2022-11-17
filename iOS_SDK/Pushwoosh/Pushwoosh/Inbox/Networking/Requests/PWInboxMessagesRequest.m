//
//  PWInboxMessagesRequest.m
//  Pushwoosh.ios
//
//  Created by Victor Eysner on 19/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInboxMessagesRequest.h"
#import "PWInboxMessageInternal.h"

@interface PWInboxMessagesRequest ()

@property (nonatomic) NSInteger limit;
@property (nonatomic) NSString *inboxCode;
@property (nonatomic) NSDate *lastRequestTime;

@end

@implementation PWInboxMessagesRequest

- (instancetype)initWithLastInboxCode:(NSString *)inboxCode limit:(NSInteger)limit lastRequestTime:(NSDate *)lastRequestTime {
    if (self = [super init]) {
        _inboxCode = inboxCode;
        _limit = limit;
        _lastRequestTime = lastRequestTime;
    }
    return self;
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [self baseDictionary];
    dict[@"last_code"] = _inboxCode ?: @"";
    dict[@"count"] = @(_limit);
    dict[@"last_request_time"] = _lastRequestTime ? @(_lastRequestTime.timeIntervalSince1970) : @(0);
    return dict;
}

- (NSString *)methodName {
    return @"getInboxMessages";
}

- (void)parseResponse:(NSDictionary *)response {
    NSArray *messages = [response pw_arrayForKey:@"messages"];
    NSMutableDictionary<NSString *, PWInboxMessageInternal *> *list = [NSMutableDictionary new];
    for (NSDictionary *dictionaryMessage in messages) {
        PWInboxMessageInternal *message = [PWInboxMessageInternal messageWithDictionary:dictionaryMessage];
        if (message) {
            [list setObject:message forKey:message.code];
        }
    }
    _messages = list;
}

@end
