//
//  PWRetryQueueStorage.h
//  Pushwoosh
//
//  Created by André Kis
//

#import <Foundation/Foundation.h>

@class PWRetryEntry;

NS_ASSUME_NONNULL_BEGIN

/// Atomic, versioned persistence for the retry queue, backed by a single file.
/// Knows nothing about scheduling or policy — just turns an array of entries into
/// bytes and back. Not internally synchronized: the owning `PWRetryQueue` calls it
/// only from its serial queue.
@interface PWRetryQueueStorage : NSObject

/// Convenience storage at the SDK's standard location
/// (`Application Support/PWRetryQueue`).
+ (instancetype)defaultStorage;

- (instancetype)initWithFileURL:(NSURL *)fileURL NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Reads persisted entries. Returns an empty array for a missing file, unreadable
/// data, a schema-version mismatch, or any decode error — never throws.
- (NSArray<PWRetryEntry *> *)loadEntries;

/// Atomically writes `entries`, applying file protection. Returns NO on failure.
- (BOOL)saveEntries:(NSArray<PWRetryEntry *> *)entries;

/// Removes the backing file entirely (full reset). The queue does not call this on
/// drain — an empty queue is persisted as an empty array via `saveEntries:` — so
/// this is for an explicit wipe.
- (void)deleteStorage;

@end

NS_ASSUME_NONNULL_END
