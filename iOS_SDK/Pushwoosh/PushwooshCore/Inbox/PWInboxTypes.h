//
//  PWInboxTypes.h
//  PushwooshCore
//
//  Created by André Kis on 21.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PWInboxMessageType) {
    PWInboxMessageTypePlain = 0,
    PWInboxMessageTypeRichmedia = 1,
    PWInboxMessageTypeURL = 2,
    PWInboxMessageTypeDeeplink = 3
};

@protocol PWInboxMessageProtocol <NSObject>

@required

@property (readonly, nonatomic, null_unspecified) NSString *code;
@property (readonly, nonatomic, null_unspecified) NSString *title;
@property (readonly, nonatomic, null_unspecified) NSString *imageUrl;
@property (readonly, nonatomic, null_unspecified) NSString *message;
@property (readonly, nonatomic, null_unspecified) NSDate *sendDate;
@property (readonly, nonatomic) PWInboxMessageType type;
@property (readonly, nonatomic) BOOL isRead;
@property (readonly, nonatomic) BOOL isActionPerformed;
@property (readonly, nonatomic, null_unspecified) NSDictionary *actionParams;
@property (readonly, nonatomic, null_unspecified) NSString *attachmentUrl;

/// The tab this message belongs to, an `identifier` of `Pushwoosh.inbox.getTabs()`; `nil` or an unknown id = "All" only.
@property (readonly, nonatomic, nullable) NSString *tabId;

@end
