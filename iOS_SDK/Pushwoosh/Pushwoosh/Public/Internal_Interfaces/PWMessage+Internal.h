//
//  PWMessage+Internal.h
//  Pushwoosh
//
//  Created by Fectum on 28.02.2020.
//  Copyright © 2020 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PWMessage;

@interface PWMessage ()

- (instancetype)initWithPayload:(NSDictionary *)payload foreground:(BOOL)foreground;

/// YES when `aps.content-available` is truthy (`1`, `"1"`) and `aps.alert` is missing, `NSNull` or empty;
/// any other alert value counts as visible. The one rule behind open and received decisions.
+ (BOOL)isSilentPush:(NSDictionary *)userInfo;

/// YES for a push with an alert and a truthy `aps.content-available`: it wakes the app and is tapped later.
+ (BOOL)isVisibleContentAvailablePush:(NSDictionary *)userInfo;

@end
