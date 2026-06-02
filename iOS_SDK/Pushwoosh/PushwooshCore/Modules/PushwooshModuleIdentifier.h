//
//  PushwooshModuleIdentifier.h
//  PushwooshCore
//
//  Created by André Kis on 21.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * PushwooshModuleIdentifier NS_TYPED_ENUM NS_SWIFT_NAME(PushwooshModuleIdentifier);

FOUNDATION_EXPORT PushwooshModuleIdentifier const PWModuleIdentifierLiveActivities NS_SWIFT_NAME(liveActivities);
FOUNDATION_EXPORT PushwooshModuleIdentifier const PWModuleIdentifierInboxKit NS_SWIFT_NAME(inboxKit);
FOUNDATION_EXPORT PushwooshModuleIdentifier const PWModuleIdentifierVoIP NS_SWIFT_NAME(voIP);
FOUNDATION_EXPORT PushwooshModuleIdentifier const PWModuleIdentifierForegroundPush NS_SWIFT_NAME(foregroundPush);
FOUNDATION_EXPORT PushwooshModuleIdentifier const PWModuleIdentifierTVoS NS_SWIFT_NAME(tvOS);
FOUNDATION_EXPORT PushwooshModuleIdentifier const PWModuleIdentifierKeychain NS_SWIFT_NAME(keychain);

NS_ASSUME_NONNULL_END
