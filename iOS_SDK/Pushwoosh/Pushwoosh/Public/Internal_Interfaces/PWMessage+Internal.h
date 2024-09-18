//
//  PWMessage+PWMessage_Internal.h
//  Pushwoosh
//
//  Created by Fectum on 28.02.2020.
//  Copyright © 2020 Pushwoosh. All rights reserved.
//

#import <PushwooshFramework/PushwooshFramework.h>

@interface PWMessage ()

- (instancetype)initWithPayload:(NSDictionary *)payload foreground:(BOOL)foreground;

+ (BOOL)isContentAvailablePush:(NSDictionary *)userInfo;

@end

