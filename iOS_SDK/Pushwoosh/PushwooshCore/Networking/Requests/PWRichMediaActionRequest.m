//
//  PWRichMediaAction.m
//  Pushwoosh
//
//  Created by Andrei Kiselev on 14.6.23..
//  Copyright © 2023 Pushwoosh. All rights reserved.
//

#import "PWRichMediaActionRequest.h"

@implementation PWRichMediaActionRequest

- (NSString *)methodName {
    return @"richMediaAction";
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dictionary = self.baseDictionary;
    
    if (_richMediaCode) {
        dictionary[@"rich_media_code"] = [_richMediaCode isEqualToString:@""] ? @"" : [_richMediaCode substringFromIndex:2];
    }
    
    if (_inAppCode) {
        dictionary[@"inapp_code"] = _inAppCode;
    }
    
    if (_messageHash) {
        dictionary[@"message_hash"] = _messageHash;
    }
    
    if (_actionAttributes) {
        dictionary[@"action_attributes"] = _actionAttributes;
    }
    
    dictionary[@"action_type"] = _actionType;
    
    return dictionary;
}

@end
