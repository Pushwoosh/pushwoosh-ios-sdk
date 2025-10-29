//
//  PWInboxMessageInternal.m
//  Pushwoosh
//
//  Created by Victor Eysner on 19/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInboxMessageInternal.h"
#import "PWInboxMessageInternal+Status.h"
#import "NSDictionary+PWDictUtils.h"

typedef NS_ENUM(NSInteger, PWInboxMessageSourceType) {
    PWInboxMessageSourceTypeNotification = 0,
    PWInboxMessageSourceTypeService = 1
};

@interface PWInboxMessageInternal ()

@property (nonatomic) NSDictionary *actionParams;
@property (nonatomic) PWInboxMessageStatus status;
@property (nonatomic) PWInboxMessageSourceType sourceType;

@end

@implementation PWInboxMessageInternal

+ (instancetype)messageWithDictionary:(NSDictionary *)dictionary {
    if (![self.class validateDictionary:dictionary]) {
        return nil;
    } else {
        PWInboxMessageInternal *message = [PWInboxMessageInternal new];
        [message updateWithDictionary:dictionary];
        return message;
    }
}

+ (BOOL)validateDictionary:(NSDictionary *)dictionary {
    BOOL result = YES;
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        result = NO;
    }
    if (![dictionary objectForKey:@"inbox_id"] ||
        ![dictionary objectForKey:@"order"] ||
        ![dictionary objectForKey:@"rt"] ||
        ![dictionary objectForKey:@"text"] ||
        ![dictionary objectForKey:@"action_type"] ||
        ![dictionary objectForKey:@"status"]
        ) {
        result = NO;
    }
    return result;
}

- (PWInboxMessageType)typeForNumber:(NSNumber *)actionType {
    return PWInboxMessageTypePlain;
}

- (void)updateType {
    if (_actionParams[@"h"] ||
        _actionParams[@"rm"] ||
        _actionParams[@"r"]) {
        _type = PWInboxMessageTypeRichmedia;
    }
    NSString *linkUrl = _actionParams[@"l"];
    if (linkUrl) {
        if ([linkUrl hasPrefix:@"http"]) {
            _type = PWInboxMessageTypeURL;
        } else {
            _type = PWInboxMessageTypeDeeplink;
        }
    }
    
}

- (NSDictionary *)parseString:(NSString *)string {
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding]
                                                             options:NSJSONReadingMutableContainers
                                                               error:nil];
    
    if (![result isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    return result;
}

- (void)updateWithDictionary:(NSDictionary *)dictionary {
    _sourceType = PWInboxMessageSourceTypeService;
    _code = [dictionary pw_stringForKey:@"inbox_id"];
    _sortOrder = [dictionary pw_forceStringForKey:@"order"];
    _title = [dictionary pw_stringForKey:@"title"];
    _message = [dictionary pw_stringForKey:@"text"];
    _inboxHash = [dictionary pw_stringForKey:@"hash"];
    _sendDate = [NSDate dateWithTimeIntervalSince1970:[dictionary pw_doubleForKey:@"send_date"]];
    _expirationDate = [NSDate dateWithTimeIntervalSince1970:[dictionary pw_doubleForKey:@"rt"]];
    _imageUrl = [dictionary pw_stringForKey:@"image"];
    NSNumber *actionType = [dictionary pw_numberForKey:@"action_type"];
    _type = [self typeForNumber:actionType];
    _actionParams = [self parseString:[dictionary pw_stringForKey:@"action_params"]];
    if (_actionParams != nil) {
        NSString *urlCandidate = [_actionParams valueForKey:@"attachment"];
        if ([urlCandidate hasPrefix:@"http://"] || [urlCandidate hasPrefix:@"https://"]) {
            _attachmentUrl = urlCandidate;
        }
    }
    NSNumber *status = [dictionary pw_numberForKey:@"status"];
    [self updateStatus:[status integerValue]];
    [self updateType];
}

#pragma mark - PushNotification methods

+ (instancetype)messageWithPushNotification:(NSDictionary *)userInfo {
    if (![self.class isInboxPushNotification:userInfo]) {
        return nil;
    } else {
        PWInboxMessageInternal *message = [PWInboxMessageInternal new];
        [message updateWithPushNotification:userInfo];
        return message;
    }
}

+ (BOOL)isInboxPushNotification:(NSDictionary *)userInfo {
    NSString *inboxCode = [userInfo pw_stringForKey:@"pw_inbox"];
    NSDictionary *inboxParams = [userInfo pw_dictionaryForKey:@"inbox_params"];
    NSString *expirationDate = [inboxParams pw_stringForKey:@"rt"];
    if (expirationDate && inboxParams && inboxCode) {
        return YES;
    } else {
        return NO;
    }
}

+ (BOOL)isFromNotification:(PWInboxMessageInternal *)message {
    return message.isFromNotification;
}

- (void)updateWithPushNotification:(NSDictionary *)dictionary {
    _sourceType = PWInboxMessageSourceTypeNotification;
    _code = [dictionary pw_stringForKey:@"pw_inbox"];
    NSDictionary *alert = [[dictionary pw_dictionaryForKey:@"aps"] pw_dictionaryForKey:@"alert"];
    _sendDate = [NSDate date];
    if (alert) {
        _title = [alert pw_stringForKey:@"title"];
        _message = [alert pw_stringForKey:@"body"];
    } else {
        _message = [[dictionary pw_dictionaryForKey:@"aps"] pw_stringForKey:@"alert"];
    }
    NSDictionary *inboxParams = [dictionary pw_dictionaryForKey:@"inbox_params"];
    _imageUrl = [inboxParams pw_stringForKey:@"image"];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    _expirationDate = [formatter dateFromString:[inboxParams pw_stringForKey:@"rt"]];
    
    NSNumber *actionType = [dictionary pw_numberForKey:@"action_type"];
    _type = [self typeForNumber:actionType];
    _actionParams = dictionary;
    _isFromNotification = true;
    [self updateType];
}

#pragma mark - NSCoder

- (void)encodeWithCoder:(NSCoder *)aCoder {
    //public
    [aCoder encodeObject:_code forKey:@"code"];
    [aCoder encodeObject:_title forKey:@"title"];
    [aCoder encodeObject:_message forKey:@"message"];
    [aCoder encodeObject:_sendDate forKey:@"sendDate"];
    [aCoder encodeObject:_imageUrl forKey:@"imageUrl"];
    [aCoder encodeInteger:_type forKey:@"type"];
    
    //private
    [aCoder encodeObject:_inboxHash forKey:@"inboxHash"];
    [aCoder encodeObject:_sortOrder forKey:@"sortOrder"];
    [aCoder encodeObject:_expirationDate forKey:@"expirationDate"];
    [aCoder encodeObject:_actionParams forKey:@"actionParams"];
    [aCoder encodeInteger:_status forKey:@"status"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    //public
    _code = [aDecoder decodeObjectOfClass:NSString.class forKey:@"code"];
    _title = [aDecoder decodeObjectOfClass:NSString.class forKey:@"title"];
    _message = [aDecoder decodeObjectOfClass:NSString.class forKey:@"message"];
    _sendDate = [aDecoder decodeObjectOfClass:NSDate.class forKey:@"sendDate"];
    _imageUrl = [aDecoder decodeObjectOfClass:NSString.class forKey:@"imageUrl"];
    _type = [aDecoder decodeIntegerForKey:@"type"];
    
    //private
    _inboxHash = [aDecoder decodeObjectOfClass:NSString.class forKey:@"inboxHash"];
    _sortOrder = [aDecoder decodeObjectOfClass:NSString.class forKey:@"sortOrder"];
    _expirationDate = [aDecoder decodeObjectOfClass:NSDate.class forKey:@"expirationDate"];
    _actionParams = [aDecoder decodeObjectOfClass:NSDictionary.class forKey:@"actionParams"];
    _status = [aDecoder decodeIntegerForKey:@"status"];
    
    return self;
}

#pragma mark -

- (BOOL)deleted {
    return (_status == PWInboxMessageStatusDeleted);
}

- (BOOL)isRead {
    return (_status == PWInboxMessageStatusRead ||
            _status == PWInboxMessageStatusAction ||
            _status == PWInboxMessageStatusDeleted ||
            _status == PWInboxMessageStatusDeletedService);
}

- (BOOL)isActionPerformed {
    return (_status == PWInboxMessageStatusAction ||
            _status == PWInboxMessageStatusDeleted ||
            _status == PWInboxMessageStatusDeletedService);
}

- (BOOL)isExpired {
    return (_expirationDate.timeIntervalSinceNow < 0.0);
}

- (BOOL)canUpdateStatus {
    return (self.sortOrder != nil);
}

@end
