//
//  PWIInboxAttachmentViewController.h
//  PushwooshInboxUI
//
//  Created by Nikolay Galizin on 31/05/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PWIInboxStyle.h"

@interface PWIInboxAttachmentViewController : UIViewController<UIViewControllerTransitioningDelegate>

@property (nonatomic) UIImageView *animationBeginView;
@property (nonatomic) NSString *attachmentUrl;

- (instancetype)initWithStyle:(PWIInboxStyle *)style;

@end
