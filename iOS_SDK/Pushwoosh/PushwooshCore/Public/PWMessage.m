//
//  PWMessage.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2024
//

#import "PWMessage.h"
#import <PushwooshCore/NSDictionary+PWDictUtils.h>
#import <PushwooshCore/PWHashDecoder.h>
#import <PushwooshCore/PWConfig.h>

@implementation PWMessage

- (instancetype)initWithPayload:(NSDictionary *)payload foreground:(BOOL)foreground {
    if (self = [super init]) {
        NSDictionary *apsDict = [payload pw_dictionaryForKey:@"aps"];
        NSString *alertString = [apsDict pw_stringForKey:@"alert"];
        NSString *hash = [payload pw_stringForKey:@"p"];

        [[PWHashDecoder sharedInstance] parseMessageHash:hash];

        _messageCode = [PWHashDecoder sharedInstance].messageCode;
        _messageId = [PWHashDecoder sharedInstance].messageId;
        _campaignId = [PWHashDecoder sharedInstance].campaignId;

        if (alertString) {
            _message = alertString;
        } else {
            NSDictionary *alertDict = [apsDict pw_dictionaryForKey:@"alert"];

            if (alertDict) {
                _message = [alertDict pw_stringForKey:@"body"];
                _title = [alertDict pw_stringForKey:@"title"];
                _subTitle = [alertDict pw_stringForKey:@"subtitle"];
            }
        }

        _link = [payload pw_stringForKey:@"l"];
        _badge = [[apsDict pw_numberForKey:@"badge"] unsignedIntValue];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:[[PWConfig config] appGroupsName]];
        _badgeExtension = [defaults integerForKey:@"badge_count"];

        NSString *customDataString = [payload pw_stringForKey:@"u"];

        if (customDataString) {
            NSDictionary *customData = [NSJSONSerialization JSONObjectWithData:[customDataString dataUsingEncoding:NSUTF8StringEncoding]
                                                                       options:0
                                                                         error:nil];

            if ([customData isKindOfClass:[NSDictionary class]]) {
                _customData = customData;
            }
        }

        _payload = payload;
        _actionIdentifier = [payload pw_stringForKey:@"actionIdentifier"];
        _contentAvailable = apsDict[@"content-available"] != nil;
        _foregroundMessage = foreground;
        _inboxMessage = apsDict[@"pw_inbox"] != nil;
    }

    return self;
}

- (NSString *)description {
    return _payload.description;
}

+ (BOOL)isContentAvailablePush:(NSDictionary *)userInfo {
    NSDictionary *apsDict = [userInfo pw_dictionaryForKey:@"aps"];
    return apsDict[@"content-available"] != nil;
}

+ (BOOL)isPushwooshMessage:(NSDictionary *)userInfo {
    return userInfo[@"pw_msg"] != nil;
}

@end
