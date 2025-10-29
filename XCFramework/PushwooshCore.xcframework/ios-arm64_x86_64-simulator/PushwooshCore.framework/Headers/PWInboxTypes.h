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

@property (readonly, nonatomic) NSString *code;
@property (readonly, nonatomic) NSString *title;
@property (readonly, nonatomic) NSString *imageUrl;
@property (readonly, nonatomic) NSString *message;
@property (readonly, nonatomic) NSDate *sendDate;
@property (readonly, nonatomic) PWInboxMessageType type;
@property (readonly, nonatomic) BOOL isRead;
@property (readonly, nonatomic) BOOL isActionPerformed;
@property (readonly, nonatomic) NSDictionary *actionParams;
@property (readonly, nonatomic) NSString *attachmentUrl;

@end
