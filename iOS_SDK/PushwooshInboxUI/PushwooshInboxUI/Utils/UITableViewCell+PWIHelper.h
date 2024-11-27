//
//  UITableViewCell+PWHelper.h
//  InboxDemo
//
//  Created by Pushwoosh on 19/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PWIInboxStyle;

@protocol PWIInboxStyleProtocol<NSObject>
@optional;

- (void)updateStyle:(PWIInboxStyle *)style;

@end

@interface UITableViewCell (PWIHelper)<PWIInboxStyleProtocol>

+ (instancetype)pwi_cellForTableView:(UITableView *)tableView style:(PWIInboxStyle *)style;

@end
