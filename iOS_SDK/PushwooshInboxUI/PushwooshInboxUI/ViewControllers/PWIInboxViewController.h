//
//  PWIInboxViewController.h
//  PushwooshInboxUI
//
//  Created by Pushwoosh on 01/11/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PWIInboxUI.h"

@class PWIInboxStyle;
@interface PWIInboxViewController (Internal)

- (instancetype)initWithStyle:(PWIInboxStyle *)style;
- (instancetype)initWithStyle:(PWIInboxStyle *)style andContentHeight:(CGFloat)contentHeight;

@end
