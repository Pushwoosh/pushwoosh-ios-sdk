//
//  UITableViewCell+PWHelper.m
//  InboxDemo
//
//  Created by Pushwoosh on 19/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "UITableViewCell+PWIHelper.h"
#import "NSBundle+PWIHelper.h"

@interface UITableViewCell (PWIStyle)

@end

@implementation UITableViewCell (PWIHelper)

+ (instancetype)pwi_loadFromNibWithStyle:(PWIInboxStyle *)style {
    NSBundle *bundle = [NSBundle pwi_bundleForClass:self];
    NSArray *loadedObjects = [bundle loadNibNamed:NSStringFromClass(self) owner:nil options:nil];
    for (id obj in loadedObjects) {
        if ([obj isKindOfClass:self]) {
            if ([obj respondsToSelector:@selector(updateStyle:)]) {
                [obj updateStyle:style];
            }
            return obj;
        }
    }
    return nil;
}

+ (instancetype)pwi_cellForTableView:(UITableView *)tableView style:(PWIInboxStyle *)style {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(self)];
    if (!cell) {
        cell = [self pwi_loadFromNibWithStyle:style];
    }
    return cell;
}

@end
