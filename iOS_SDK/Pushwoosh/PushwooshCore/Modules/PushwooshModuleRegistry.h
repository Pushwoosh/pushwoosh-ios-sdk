//
//  PushwooshModuleRegistry.h
//  PushwooshCore
//
//  Created by André Kis on 21.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PushwooshModuleIdentifier.h"

NS_ASSUME_NONNULL_BEGIN

/**
 SDK-internal registry that maps `PushwooshModuleIdentifier` values to module
 implementation classes and back-channel handler instances.

 Modules announce themselves via a per-module registrar shim whose `+load`
 calls `registerClass:forIdentifier:` (and optionally
 `registerHandler:forIdentifier:`). Core reads back through
 `classForIdentifier:` / `handlerForIdentifier:`.

 When a module is not linked, `classForIdentifier:` returns `PWMissingModule`
 (which forwards any selector to a logged no-op). `handlerForIdentifier:`
 returns `nil` — callers nil-message-send through Objective-C semantics.

 Visibility: project-only. Not exposed in `PushwooshCore.h`.
 */
@interface PushwooshModuleRegistry : NSObject

/// Registers a class as the implementation for a module identifier. Idempotent —
/// the last call wins. Safe to call from `+load`.
+ (void)registerClass:(Class)cls forIdentifier:(PushwooshModuleIdentifier)identifier;

/// Registers a back-channel handler instance for a module identifier. Idempotent.
+ (void)registerHandler:(id)handler forIdentifier:(PushwooshModuleIdentifier)identifier;

/// Returns the registered class, or `PWMissingModule.class` when none is registered.
+ (Class)classForIdentifier:(PushwooshModuleIdentifier)identifier;

/// Returns the registered handler, or `nil` when none is registered.
+ (nullable id)handlerForIdentifier:(PushwooshModuleIdentifier)identifier;

/// Test seam — drops all registrations. Not for production use.
+ (void)_resetForTesting;

@end

NS_ASSUME_NONNULL_END
