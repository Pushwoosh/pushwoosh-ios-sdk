//
//  PWIInboxUI.m
//  PushwooshInboxUI
//
//  Created by Pushwoosh on 01/11/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWIInboxUI.h"
#import "PWIInboxStyle.h"
#import "PWIInboxViewController.h"

NSString * const PushwooshInboxUIVersion = @"5.8.5";

@implementation PWIInboxUI

+ (UIViewController *)createInboxControllerWithStyle:(PWIInboxStyle *)style {
    PWIInboxViewController *inboxViewController = [[PWIInboxViewController alloc] initWithStyle:style];
    return inboxViewController;
}

+ (UIViewController *)createInboxControllerWithStyle:(PWIInboxStyle *)style andContentHeight:(CGFloat)contentHeight {
    PWIInboxViewController *inboxViewController = [[PWIInboxViewController alloc] initWithStyle:style andContentHeight:contentHeight];
    return inboxViewController;
}

@end
