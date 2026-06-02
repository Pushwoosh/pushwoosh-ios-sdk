//
//  PWVoIPConfigureHandler.h
//  PushwooshCore
//
//  Created by André Kis on 22.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Canonical Obj-C declaration of the VoIP back-channel protocol. Mirrors the
 Swift `@objc public protocol PWVoIPConfigureHandler` declared in
 `PushwooshBridge`. Same selector — runtime dispatch resolves identically
 regardless of which side the handler instance was vended from.

 Visibility: project-only. Imported by Core consumers (`PWPushRuntime.ios.m`)
 and by unit tests.
 */
@protocol PWVoIPConfigureHandler <NSObject>
- (void)configureVoIP;
@end

NS_ASSUME_NONNULL_END
