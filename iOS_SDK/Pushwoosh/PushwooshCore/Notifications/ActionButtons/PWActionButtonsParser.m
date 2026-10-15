//
//  PWActionButtonsParser.m
//  PushwooshCore
//
//  Created by André Kis on 08.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWActionButtonsParser.h"

#import <UserNotifications/UserNotifications.h>

@implementation PWActionButtonsParser

+ (NSArray<PWActionButton *> *)buttonsFromUserInfo:(NSDictionary *)userInfo {
    if (![userInfo isKindOfClass:[NSDictionary class]]) {
        return @[];
    }

    NSArray *entries = [self entriesFromPayloadValue:userInfo[PWActionButtonsPayloadKey]];
    NSMutableArray<PWActionButton *> *buttons = [NSMutableArray array];
    NSMutableSet<NSString *> *claimedIdentifiers = [NSMutableSet set];

    for (id entry in entries) {
        if (buttons.count >= PWActionButtonsLimit) {
            break;
        }

        PWActionButton *button = [self buttonFromEntry:entry];
        if (button == nil || [claimedIdentifiers containsObject:button.identifier]) {
            continue;
        }

        [claimedIdentifiers addObject:button.identifier];
        [buttons addObject:button];
    }

    return buttons;
}

+ (PWActionButton *)buttonForActionIdentifier:(NSString *)actionIdentifier inUserInfo:(NSDictionary *)userInfo {
    if (![actionIdentifier isKindOfClass:[NSString class]] || actionIdentifier.length == 0) {
        return nil;
    }

    for (PWActionButton *button in [self buttonsFromUserInfo:userInfo]) {
        if ([button.identifier isEqualToString:actionIdentifier]) {
            return button;
        }
    }

    return nil;
}

#pragma mark - Reading the payload

+ (NSArray *)entriesFromPayloadValue:(id)value {
    if (![value isKindOfClass:[NSString class]]) {
        return @[];
    }

    NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) {
        return @[];
    }

    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [parsed isKindOfClass:[NSArray class]] ? parsed : @[];
}

+ (PWActionButton *)buttonFromEntry:(id)entry {
    if (![entry isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *fields = entry;
    NSString *identifier = [self stringForKey:PWActionButtonFieldId inFields:fields];
    NSString *label = [self stringForKey:PWActionButtonFieldLabel inFields:fields];
    NSString *actionValue = [self stringForKey:PWActionButtonFieldAction inFields:fields];

    if (identifier == nil || label == nil || actionValue == nil || [self isSystemActionIdentifier:identifier]) {
        return nil;
    }

    PWActionButtonAction action;
    if (![self action:&action fromValue:actionValue]) {
        return nil;
    }

    NSString *url = nil;
    if (action == PWActionButtonActionUrl || action == PWActionButtonActionDeeplink) {
        url = [self stringForKey:PWActionButtonFieldUrl inFields:fields];
        if (url == nil) {
            return nil;
        }
    }

    NSString *style = [self stringForKey:PWActionButtonFieldStyle inFields:fields];
    BOOL destructive = [style isEqualToString:PWActionButtonStyleValueDestructive];

    return [[PWActionButton alloc] initWithIdentifier:identifier
                                                label:label
                                               action:action
                                                  url:url
                                          destructive:destructive];
}

/// iOS reserves these for a plain tap and for a dismissal; a button holding one would swallow both.
+ (BOOL)isSystemActionIdentifier:(NSString *)identifier {
#if TARGET_OS_IOS
    return [identifier isEqualToString:UNNotificationDefaultActionIdentifier]
        || [identifier isEqualToString:UNNotificationDismissActionIdentifier];
#else
    return NO;
#endif
}

+ (NSString *)stringForKey:(NSString *)key inFields:(NSDictionary *)fields {
    id value = fields[key];
    if (![value isKindOfClass:[NSString class]] || ((NSString *)value).length == 0) {
        return nil;
    }
    return value;
}

+ (BOOL)action:(PWActionButtonAction *)outAction fromValue:(NSString *)value {
    if ([value isEqualToString:PWActionButtonActionValueOpen]) {
        *outAction = PWActionButtonActionOpen;
    } else if ([value isEqualToString:PWActionButtonActionValueUrl]) {
        *outAction = PWActionButtonActionUrl;
    } else if ([value isEqualToString:PWActionButtonActionValueDeeplink]) {
        *outAction = PWActionButtonActionDeeplink;
    } else if ([value isEqualToString:PWActionButtonActionValueCustom]) {
        *outAction = PWActionButtonActionCustom;
    } else {
        return NO;
    }
    return YES;
}

@end
