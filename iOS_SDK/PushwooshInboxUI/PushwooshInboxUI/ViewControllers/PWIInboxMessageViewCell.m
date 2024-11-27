//
//  PWIInboxMessageViewCell.m
//  PushwooshInboxUI
//
//  Created by Pushwoosh on 01/11/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWIInboxMessageViewCell.h"
#import "UIImageView+PWILoadImage.h"
#import "PushwooshInboxUI.h"

@interface PWIInboxMessageViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UIImageView *inboxImageView;
@property (nonatomic) PWIInboxStyle *style;
@property (weak, nonatomic) IBOutlet UIImageView *inboxAttachmentImageView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *inboxAttachmentImageViewWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *inboxAttachmentImageViewHeightConstraint;

@property (weak, nonatomic) IBOutlet UIButton *inboxAttachmentButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *inboxAttachmentButtonHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *inboxAttachmentButtonWidthConstraint;
@property (nonatomic, copy, nullable) void (^inboxAttachmentTappedCallback)(UIImageView *, NSString *);

@end


@implementation PWIInboxMessageViewCell

- (UIEdgeInsets)layoutMargins {
    return UIEdgeInsetsZero;
}

- (void)updateStyle:(PWIInboxStyle *)style {
    _style = style;
    if (style.selectionColor) {
        self.selectedBackgroundView = [[UIView alloc] initWithFrame:self.bounds];
        self.selectedBackgroundView.backgroundColor = style.selectionColor;
    }
    _messageLabel.font = _style.descriptionFont;
    _messageLabel.textColor = _style.descriptionColor;
    _titleLabel.font = _style.titleFont;
    _titleLabel.textColor = _style.titleColor;
}

- (void)updateMessage:(NSObject<PWInboxMessageProtocol> *)message {
    _message = message;
    _titleLabel.attributedText = [self titleAttributedStringForMessage:message];
    _messageLabel.attributedText = [self textAttributedStringForMessage:message];
    [_inboxImageView pwi_loadImageFromUrl:message.imageUrl callback:nil];
    if (!message.imageUrl.length) {
        _inboxImageView.image = _style.defaultImageIcon;
    }
    NSString *attachmentUrl = message.attachmentUrl;
    if (attachmentUrl.length == 0) {
        [_inboxAttachmentImageView pwi_loadImageFromUrl:nil callback:nil];
        _inboxAttachmentImageViewWidthConstraint.constant = 0;
        _inboxAttachmentImageViewHeightConstraint.constant = 0;
        _inboxAttachmentImageView.hidden = YES;
        _inboxAttachmentButtonWidthConstraint.constant = 0;
        _inboxAttachmentButtonHeightConstraint.constant = 0;
        _inboxAttachmentButton.hidden = YES;
    } else {
        [_inboxAttachmentImageView pwi_loadImageFromUrl:attachmentUrl callback:^(UIImage *image) {
            _inboxAttachmentImageViewWidthConstraint.constant = 50;
            _inboxAttachmentImageViewHeightConstraint.constant = 50;
            _inboxAttachmentImageView.hidden = NO;
            _inboxAttachmentButtonWidthConstraint.constant = 50;
            _inboxAttachmentButtonHeightConstraint.constant = 50;
            _inboxAttachmentButton.hidden = NO;
        }];
    }
}

- (NSAttributedString *)titleAttributedStringForMessage:(NSObject<PWInboxMessageProtocol> *)message {
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] init];
    
    if (!message.isRead && _style.unreadImage) {
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        textAttachment.image = _style.unreadImage;
        textAttachment.bounds = CGRectMake(0, 0, 10, 10);
        [string appendAttributedString:[NSAttributedString attributedStringWithAttachment:textAttachment]];
        [string appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
    }
    
    if (message.title) {
        if (message.isRead && _style.readTitleColor) {
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:message.title attributes:@{NSForegroundColorAttributeName : _style.readTitleColor}]];
        } else {
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:message.title]];
        }
    }
    
    if (message.sendDate) {
        NSString *dateString = _style.dateFormatterBlock(message.sendDate, self);
        if (message.title.length > 0) {
            [string appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
        }
        [string appendAttributedString:[[NSAttributedString alloc] initWithString:dateString attributes:@{NSFontAttributeName : _style.dateFont,
                                                                                                          NSForegroundColorAttributeName : _style.dateColor
                                                                                                          }]];
    }
    return string;
}

- (NSAttributedString *)textAttributedStringForMessage:(NSObject<PWInboxMessageProtocol> *)message {
    return (message.isRead && _style.readTextColor) ? [self textMessage:message.message textColor:_style.readTextColor] : [self textMessage:message.message textColor:_style.defaultTextColor];
}

- (NSMutableAttributedString *)textMessage:(NSString *)message textColor:(UIColor *)color {
    NSMutableAttributedString *modifiedMessage = [[NSMutableAttributedString alloc] init];
    [modifiedMessage appendAttributedString:[[NSAttributedString alloc] initWithString:message attributes:@{NSForegroundColorAttributeName : color}]];
    return modifiedMessage;
}

- (IBAction)attachmentButtonTapped:(id)sender {
    _inboxAttachmentTappedCallback(_inboxAttachmentImageView, _message.attachmentUrl);
}

@end
