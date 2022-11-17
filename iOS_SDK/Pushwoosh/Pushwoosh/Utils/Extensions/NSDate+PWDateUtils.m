//
//  NSDate+PWDateUtils.m
//  Pushwoosh
//
//  Created by Fectum on 11/06/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "NSDate+PWDateUtils.h"

@implementation NSDate (PWDateUtils)

- (NSString *)pw_formattedDate {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    return [formatter stringFromDate:self];
}

@end
