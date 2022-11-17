//
//  PWInboxAllMessagesRequest.m
//  Pushwoosh
//
//  Created by Victor Eysner on 31/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInboxAllMessagesRequest.h"
#import "PWInboxMessageInternal+Status.h"

@interface PWInboxAllMessagesRequest ()

@property (nonatomic) NSDate *lastRequestTime;

@end

@implementation PWInboxAllMessagesRequest

- (instancetype)initWithLastRequestTime:(NSDate *)lastRequestTime {
    if (self = [super init]) {
        _lastRequestTime = lastRequestTime;
    }
    return self;
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [self baseDictionary];
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
        if (message && !message.deleted) {
            [list setObject:message forKey:message.code];
        }
    }
    _messages = list;
}

@end
