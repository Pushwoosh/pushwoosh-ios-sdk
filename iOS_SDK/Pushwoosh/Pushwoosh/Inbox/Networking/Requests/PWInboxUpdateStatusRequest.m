//
//  PWInboxUpdateStatusRequest.m
//  Pushwoosh
//
//  Created by Victor Eysner on 25/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInboxUpdateStatusRequest.h"
#import "PWInboxMessageInternal+Status.h"
#import "PWPreferences.h"

@interface PWInboxUpdateStatusRequest ()

@property (nonatomic) NSString *inboxCode;
@property (nonatomic) NSInteger status;
@property (nonatomic) NSString *inboxHash;

@end

@implementation PWInboxUpdateStatusRequest

+ (instancetype)deleteInboxMessage:(NSString *)inboxCode inboxHash:(NSString *)inboxHash {
    if (inboxCode) {
        return [[self alloc] initWithInboxCode:inboxCode updateStatus:[PWInboxMessageInternal deleteStatusForNetwork] inboxHash:inboxHash];
    } else {
        return nil;
    }
}

+ (instancetype)actionInboxMessage:(NSString *)inboxCode inboxHash:(NSString *)inboxHash {
    if (inboxCode) {
        return [[self alloc] initWithInboxCode:inboxCode updateStatus:[PWInboxMessageInternal actionStatusForNetwork] inboxHash:inboxHash];
    } else {
        return nil;
    }
}

+ (instancetype)readInboxMessage:(NSString *)inboxCode inboxHash:(NSString *)inboxHash {
    if (inboxCode) {
        return [[self alloc] initWithInboxCode:inboxCode updateStatus:[PWInboxMessageInternal readStatusForNetwork] inboxHash:inboxHash];
    } else {
        return nil;
    }
}

- (instancetype)initWithInboxCode:(NSString *)inboxCode updateStatus:(NSInteger)status inboxHash:(NSString *)inboxHash {
    if (self = [super init]) {
        _inboxCode = inboxCode;
        _status = status;
        _inboxHash = inboxHash;
    }
    return self;
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dictionary = [self baseDictionary];
    dictionary[@"inbox_code"] = _inboxCode;
    dictionary[@"status"] = @(_status);
    if (_inboxHash) {
        dictionary[@"hash"] = _inboxHash;
    }
    return dictionary;
}

- (NSString *)methodName {
    return @"inboxStatus";
}


@end
