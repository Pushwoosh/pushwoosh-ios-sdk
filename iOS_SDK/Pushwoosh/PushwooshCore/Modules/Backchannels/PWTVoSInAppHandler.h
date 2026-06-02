//
//  PWTVoSInAppHandler.h
//  PushwooshCore
//
//  Created by André Kis on 22.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Canonical Obj-C declaration of the tvOS in-app back-channel protocol. Mirrors
 the Swift `@objc public protocol PWTVoSInAppHandler` declared in
 `PushwooshBridge`. Same selector — runtime dispatch resolves identically
 regardless of which side the handler instance was vended from.

 Visibility: project-only. Imported by Core consumers
 (`PWInAppMessagesManager.m`) and by unit tests.
 */
@protocol PWTVoSInAppHandler <NSObject>
- (void)handleInAppResource:(id)resource;
@end

NS_ASSUME_NONNULL_END
