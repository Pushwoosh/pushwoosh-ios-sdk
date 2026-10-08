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

/// YES when `aps.content-available` is truthy (`1`, `"1"`) and `aps.alert` is missing, `NSNull` or empty;
/// any other alert value counts as visible. The one rule behind open and received decisions.
+ (BOOL)isSilentPush:(NSDictionary *)userInfo;

/// YES for a push with an alert and a truthy `aps.content-available`: it wakes the app and is tapped later.
+ (BOOL)isVisibleContentAvailablePush:(NSDictionary *)userInfo;

@end
