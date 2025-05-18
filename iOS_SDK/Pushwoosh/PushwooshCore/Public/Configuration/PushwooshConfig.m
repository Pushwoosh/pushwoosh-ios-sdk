//
//  PushwooshConfig.m
//  PushwooshCore
//
//  Created by André Kis on 16.04.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PushwooshConfig.h"

@implementation PushwooshConfig

+ (Class<PWConfiguration>)Configuration {
    return self;
}

+ (void)setApiToken:(NSString *)apiToken {
    [[PWSettings settings] setApiToken:apiToken];
}

+ (NSString *)getApiToken {
    return [[PWSettings settings] apiToken];
}

@end
