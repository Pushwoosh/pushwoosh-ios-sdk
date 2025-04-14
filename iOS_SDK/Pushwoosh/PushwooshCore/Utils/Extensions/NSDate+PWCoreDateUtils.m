//
//  NSDate+PWCoreDateUtils.m
//  PushwooshCore
//
//  Created by André Kis on 12.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "NSDate+PWCoreDateUtils.h"

@implementation NSDate (PWCoreDateUtils)

- (NSString *)pw_formattedDate {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    return [formatter stringFromDate:self];
}

@end
