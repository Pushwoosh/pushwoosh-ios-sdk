//
//  PWIInboxMessageViewCell.h
//  PushwooshInboxUI
//
//  Created by Pushwoosh on 01/11/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UITableViewCell+PWIHelper.h"
#import "PWInbox.h"

@class PWIInboxStyle;
@interface PWIInboxMessageViewCell : UITableViewCell

@property (readonly, nonatomic) NSObject<PWInboxMessageProtocol> *message;

- (void)updateStyle:(PWIInboxStyle *)style;
- (void)updateMessage:(NSObject<PWInboxMessageProtocol> *)message;
- (void)setInboxAttachmentTappedCallback:(void (^)(UIImageView *, NSString *))inboxAttachmentTappedCallback;
@end
