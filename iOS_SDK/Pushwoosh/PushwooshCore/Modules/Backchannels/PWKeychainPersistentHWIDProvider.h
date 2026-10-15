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
/// Creates a new HWID, stores it in the keychain and returns it; `nil` when the keychain rejects it.
- (nullable NSString *)persistentHWID;
/// Returns the HWID stored in the keychain without creating one; `nil` when absent or unreadable.
- (nullable NSString *)storedPersistentHWID;
/// Stores `hwid` in the keychain; `NO` when the keychain rejects it.
- (BOOL)storePersistentHWID:(NSString *)hwid;
@end

/// Posted by the Keychain module loader right after it registers its handler, so a `PWPreferences`
/// created before the module loaded can reconcile its HWID with the keychain.
FOUNDATION_EXPORT NSNotificationName const PWKeychainPersistentHWIDProviderDidRegisterNotification;

NS_ASSUME_NONNULL_END
