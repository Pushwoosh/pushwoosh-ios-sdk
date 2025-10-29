//
//  PWMessage+Internal.h
//  PushwooshCore
//
//  Created by André Kis on 20.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <PushwooshCore/PWMessage.h>

@interface PWMessage ()

- (instancetype)initWithPayload:(NSDictionary *)payload foreground:(BOOL)foreground;

+ (BOOL)isContentAvailablePush:(NSDictionary *)userInfo;

@end
