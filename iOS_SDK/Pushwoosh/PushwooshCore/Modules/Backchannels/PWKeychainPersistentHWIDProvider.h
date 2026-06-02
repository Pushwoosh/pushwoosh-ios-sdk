//
//  PWKeychainPersistentHWIDProvider.h
//  PushwooshCore
//
//  Created by André Kis on 22.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Canonical Obj-C declaration of the Keychain back-channel protocol. Mirrors the
 Swift `@objc public protocol PWKeychainPersistentHWIDProvider` declared in
 `PushwooshBridge`; both share the same Obj-C selectors so `id<PWKeychainPersistentHWIDProvider>`
 dispatch resolves regardless of which side the handler instance was vended
 from.

 Visibility: project-only. Imported by Core consumers (`PWPreferences.m`) and
 by unit tests; never promoted to `PushwooshCore.h`.
 */
@protocol PWKeychainPersistentHWIDProvider <NSObject>
@property (nonatomic, readonly) BOOL isPersistentHWIDEnabled;
- (nullable NSString *)persistentHWID;
@end

NS_ASSUME_NONNULL_END
