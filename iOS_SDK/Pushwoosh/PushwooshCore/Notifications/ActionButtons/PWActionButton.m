//
//  PWActionButton.m
//  PushwooshCore
//
//  Created by André Kis on 08.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWActionButton.h"

NSString * const PWActionButtonsPayloadKey = @"pw_buttons";
NSString * const PWActionButtonFieldId = @"id";
NSString * const PWActionButtonFieldLabel = @"label";
NSString * const PWActionButtonFieldAction = @"action";
NSString * const PWActionButtonFieldUrl = @"url";
NSString * const PWActionButtonFieldStyle = @"style";
NSString * const PWActionButtonActionValueOpen = @"open";
NSString * const PWActionButtonActionValueUrl = @"url";
NSString * const PWActionButtonActionValueDeeplink = @"deeplink";
NSString * const PWActionButtonActionValueCustom = @"custom";
NSString * const PWActionButtonStyleValueDestructive = @"destructive";
NSString * const PWActionButtonStatField = @"button_id";
NSString * const PWActionIdentifierKey = @"actionIdentifier";
NSString * const PWActionButtonsCategoryPrefix = @"pw_";
const NSUInteger PWActionButtonsLimit = 3;
const NSUInteger PWActionButtonsCategoryLimit = 20;

@implementation PWActionButton

- (instancetype)initWithIdentifier:(NSString *)identifier
                             label:(NSString *)label
                            action:(PWActionButtonAction)action
                               url:(NSString *)url
                       destructive:(BOOL)destructive {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _label = [label copy];
        _action = action;
        _url = [url copy];
        _destructive = destructive;
    }
    return self;
}

- (BOOL)opensApplication {
    return _action != PWActionButtonActionCustom;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PWActionButton %@ action=%ld url=%@ destructive=%d>",
            _identifier, (long)_action, _url, _destructive];
}

@end
