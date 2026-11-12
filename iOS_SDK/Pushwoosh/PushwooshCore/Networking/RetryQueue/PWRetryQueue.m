/*
 *  PWRetryQueue.m
 *  Pushwoosh
 *
 *  Created by André Kis
 */

#import "PWRetryQueue.h"
#import "PWRetryEntry.h"
#import "PWRetryPolicy.h"
#import "PWRetryQueueStorage.h"
#import "PWUtils.h"
#import "PWRequest+Internal.h"
#import <PushwooshCore/PWRequest.h>
#import <PushwooshCore/PWPreferences.h>
#import <PushwooshCore/PushwooshLog.h>

NSNotificationName const PWRetryQueueDidDeliverRequestNotification = @"PWRetryQueueDidDeliverRequestNotification";
NSString *const PWRetryQueueMethodNameKey = @"methodName";
NSString *const PWRetryQueueBodyKey = @"body";

@interface PWRetryQueue ()
@property (nonatomic, weak) id<PWRetryTransport> transport;
@property (nonatomic, strong) PWRetryPolicy *policy;
@property (nonatomic, strong) PWRetryQueueStorage *storage;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableArray<PWRetryEntry *> *entries;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *inFlight;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *inFlightSince;
@property (nonatomic, assign) NSUInteger sendCounter;
@property (nonatomic, strong) NSDate *scheduledWakeDate;
@property (nonatomic, assign) NSUInteger wakeGeneration;
@end

@implementation PWRetryQueue

- (instancetype)initWithTransport:(id<PWRetryTransport>)transport
                           policy:(PWRetryPolicy *)policy
                          storage:(PWRetryQueueStorage *)storage {
    if (self = [super init]) {
        _transport = transport;
        _policy = policy;
        _storage = storage;
        _serialQueue = dispatch_queue_create("com.pushwoosh.retryqueue", DISPATCH_QUEUE_SERIAL);
        _inFlight = [NSMutableDictionary dictionary];
        _inFlightSince = [NSMutableDictionary dictionary];
        _entries = [NSMutableArray array];

        __weak typeof(self) wSelf = self;
        dispatch_async(_serialQueue, ^{
            typeof(self) sSelf = wSelf;
            if (!sSelf) return;
            sSelf.entries = [[sSelf.storage loadEntries] mutableCopy] ?: [NSMutableArray array];
            [sSelf wakeEntriesAwaitingNetworkLocked];
            [sSelf flushLocked];
        });
    }
    return self;
}

#pragma mark - Public

- (void)enqueueRequest:(PWRequest *)request {
    [self enqueueRequest:request baseUrl:request.baseUrl];
}

- (void)enqueueRequest:(PWRequest *)request baseUrl:(NSString *)baseUrl {
    NSString *identifier = request.requestIdentifier;
    PWRetryEntry *entry = [[PWRetryEntry alloc] initWithRequest:request baseUrl:baseUrl now:[NSDate date]];
    NSUInteger limit = [request retryQueueLimit];

    __weak typeof(self) wSelf = self;
    dispatch_async(_serialQueue, ^{
        typeof(self) sSelf = wSelf;
        if (!sSelf) return;
        if ([sSelf entryForIdentifierLocked:identifier] != nil) {
            return;
        }
        if (limit > 0) {
            [sSelf makeRoomForEntryOfMethodLocked:entry.methodName limit:limit];
        }
        [sSelf.entries addObject:entry];
        [sSelf.storage saveEntries:sSelf.entries];
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:sSelf
                           message:[NSString stringWithFormat:@"Queued %@ for retry (host: %@%@)", entry.methodName, entry.baseUrl ?: @"(current)", entry.survivesApplicationChange ? @", survives application change" : @""]];
        [sSelf flushLocked];
    });
}

- (void)purgeAllEntriesWithReason:(NSString *)reason {
    __weak typeof(self) wSelf = self;
    dispatch_async(_serialQueue, ^{
        typeof(self) sSelf = wSelf;
        if (!sSelf) return;

        /// Entries that describe the application being left (the unregister) must still be delivered
        /// there — the purge keeps them and drops only the ones scoped to the vacated application.
        NSArray<PWRetryEntry *> *survivors = [sSelf.entries filteredArrayUsingPredicate:
                                              [NSPredicate predicateWithBlock:^BOOL(PWRetryEntry *entry, NSDictionary *bindings) {
            return entry.survivesApplicationChange;
        }]];
        NSUInteger dropped = sSelf.entries.count - survivors.count;
        NSMutableSet *survivorIdentifiers = [NSMutableSet set];
        for (PWRetryEntry *entry in survivors) {
            [survivorIdentifiers addObject:entry.requestIdentifier];
        }
        [sSelf.entries setArray:survivors];
        for (NSString *identifier in [sSelf.inFlight.allKeys copy]) {
            if (![survivorIdentifiers containsObject:identifier]) {
                [sSelf.inFlight removeObjectForKey:identifier];
                [sSelf.inFlightSince removeObjectForKey:identifier];
            }
        }
        [sSelf.storage saveEntries:sSelf.entries];

        if (dropped > 0) {
            [PushwooshLog pushwooshLog:PW_LL_WARN className:sSelf
                               message:[NSString stringWithFormat:@"Dropped %lu queued retry entries: %@", (unsigned long)dropped, reason]];
        }
        [sSelf scheduleWakeLocked:[NSDate date]];
    });
}

- (void)flush {
    __weak typeof(self) wSelf = self;
    dispatch_async(_serialQueue, ^{
        [wSelf flushLocked];
    });
}

- (void)onNetworkReachable {
    __weak typeof(self) wSelf = self;
    dispatch_async(_serialQueue, ^{
        typeof(self) sSelf = wSelf;
        if (!sSelf) return;
        [sSelf wakeEntriesAwaitingNetworkLocked];
        [sSelf flushLocked];
    });
}

#pragma mark - Serial-queue internals

/// The app code and the host feed two independent decisions (staleness vs retargeting) and are read
/// from two sources on purpose — the host comes from the transport, which applies a reverse proxy.
- (void)flushLocked {
    NSDate *now = [NSDate date];
    BOOL mutated = NO;

    BOOL scopeResolved = NO;
    BOOL applicationScoped = NO;
    NSString *currentAppCode = nil;
    NSString *currentBaseUrl = nil;

    for (PWRetryEntry *entry in [_entries copy]) {
        NSString *identifier = entry.requestIdentifier;

        if (!scopeResolved) {
            scopeResolved = YES;
            applicationScoped = [PWPreferences hasActiveApplicationRecord];
            currentAppCode = [PWPreferences preferences].appCode;
            if (applicationScoped) {
                currentBaseUrl = [_transport currentBaseUrlForRetry];
            }
        }

        if ([self isEntry:entry staleForAppCode:currentAppCode applicationScoped:applicationScoped]) {
            [self dropEntryLocked:identifier];
            mutated = YES;
            NSString *reason = entry.survivesApplicationChange
                ? @"the device is back in the application it was meant to leave"
                : @"it belongs to a Pushwoosh application that is no longer active";
            [PushwooshLog pushwooshLog:PW_LL_WARN className:self
                               message:[NSString stringWithFormat:@"Dropping retry entry %@: %@", entry.methodName, reason]];
            continue;
        }

        if ([_policy isExpiredFirstEnqueuedDate:entry.firstEnqueuedDate now:now]) {
            [self dropEntryLocked:identifier];
            mutated = YES;
            [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self
                               message:[NSString stringWithFormat:@"Dropping expired retry entry %@", entry.methodName]];
            continue;
        }
        if ([_policy isExhaustedAttemptCount:entry.attemptCount]) {
            [self dropEntryLocked:identifier];
            mutated = YES;
            [PushwooshLog pushwooshLog:PW_LL_WARN className:self
                               message:[NSString stringWithFormat:@"Dropping retry entry %@ after %lu attempts", entry.methodName, (unsigned long)entry.attemptCount]];
            continue;
        }

        if (_inFlight[identifier] != nil) {
            NSDate *since = _inFlightSince[identifier];
            if (since != nil && [now timeIntervalSinceDate:since] < _policy.inFlightTimeout) {
                continue;
            }
            [self clearInFlightLocked:identifier];
            if ([_policy isExhaustedAttemptCount:entry.attemptCount + 1]) {
                [self removeEntryLocked:identifier];
                mutated = YES;
                [PushwooshLog pushwooshLog:PW_LL_WARN className:self
                                   message:[NSString stringWithFormat:@"Dropping stuck in-flight retry %@ after %lu attempts", entry.methodName, (unsigned long)(entry.attemptCount + 1)]];
                continue;
            }
            NSTimeInterval delay = [_policy delayForAttempt:entry.attemptCount];
            [self replaceEntryLocked:[entry entryByIncrementingAttemptWithNextDate:[now dateByAddingTimeInterval:delay]]];
            mutated = YES;
            [PushwooshLog pushwooshLog:PW_LL_WARN className:self
                               message:[NSString stringWithFormat:@"Reclaiming stuck in-flight retry %@", entry.methodName]];
            continue;
        }

        if ([entry.nextAttemptDate timeIntervalSinceDate:now] > 0) {
            continue;
        }
        if ([self isEntryHeldUntilReadyLocked:entry]) {
            continue;
        }

        NSUInteger token = ++_sendCounter;
        _inFlight[identifier] = @(token);
        _inFlightSince[identifier] = now;
        PWRetryEntry *outgoing = applicationScoped ? [self entryRetargetedToCurrentHost:entry baseUrl:currentBaseUrl] : entry;
        __weak typeof(self) wSelf = self;
        [_transport sendRetryEntry:outgoing completion:^(NSInteger statusCode, NSError *error) {
            [wSelf handleResultForEntry:entry token:token statusCode:statusCode error:error];
        }];
    }

    if (mutated) {
        [_storage saveEntries:_entries];
    }
    [self scheduleWakeLocked:now];
}

- (void)handleResultForEntry:(PWRetryEntry *)entry token:(NSUInteger)token statusCode:(NSInteger)statusCode error:(NSError *)error {
    NSString *identifier = entry.requestIdentifier;
    __weak typeof(self) wSelf = self;
    dispatch_async(_serialQueue, ^{
        typeof(self) sSelf = wSelf;
        if (!sSelf) return;

        NSNumber *currentToken = sSelf.inFlight[identifier];
        if (currentToken == nil || currentToken.unsignedIntegerValue != token) {
            return;
        }
        [sSelf clearInFlightLocked:identifier];

        if (error == nil) {
            [sSelf removeEntryLocked:identifier];
            [sSelf.storage saveEntries:sSelf.entries];
            if (entry.announcesDelivery) {
                NSDictionary *delivered = @{PWRetryQueueMethodNameKey: entry.methodName ?: @"",
                                            PWRetryQueueBodyKey: entry.requestDictionary ?: @{}};
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:PWRetryQueueDidDeliverRequestNotification
                                                                        object:sSelf
                                                                      userInfo:delivered];
                });
            }
            [sSelf flushLocked];
            return;
        }

        if (![sSelf.policy shouldRetryStatusCode:statusCode error:error]) {
            [sSelf removeEntryLocked:identifier];
            [sSelf.storage saveEntries:sSelf.entries];
            [PushwooshLog pushwooshLog:PW_LL_WARN className:sSelf
                               message:[NSString stringWithFormat:@"Dropping retry entry %@ on permanent error", entry.methodName]];
            return;
        }

        PWRetryEntry *current = [sSelf entryForIdentifierLocked:identifier];
        if (current == nil) {
            return;
        }

        if (current.waitsForNetwork && [sSelf.policy isOfflineError:error]) {
            [sSelf replaceEntryLocked:[current entryAwaitingNetworkUntil:[NSDate dateWithTimeIntervalSinceNow:sSelf.policy.maxDelay]]];
            [sSelf.storage saveEntries:sSelf.entries];
            [PushwooshLog pushwooshLog:PW_LL_DEBUG className:sSelf
                               message:[NSString stringWithFormat:@"Retry entry %@ waits for the network", current.methodName]];
            [sSelf scheduleWakeLocked:[NSDate date]];
            return;
        }

        if ([sSelf.policy isExhaustedAttemptCount:current.attemptCount + 1]) {
            [sSelf removeEntryLocked:identifier];
            [sSelf.storage saveEntries:sSelf.entries];
            [PushwooshLog pushwooshLog:PW_LL_WARN className:sSelf
                               message:[NSString stringWithFormat:@"Dropping retry entry %@ after %lu attempts", current.methodName, (unsigned long)(current.attemptCount + 1)]];
            return;
        }

        NSTimeInterval delay = [sSelf.policy delayForAttempt:current.attemptCount];
        [sSelf replaceEntryLocked:[current entryByIncrementingAttemptWithNextDate:[NSDate dateWithTimeIntervalSinceNow:delay]]];
        [sSelf.storage saveEntries:sSelf.entries];
        [sSelf scheduleWakeLocked:[NSDate date]];
    });
}

- (void)scheduleWakeLocked:(NSDate *)now {
    NSDate *earliest = nil;
    for (PWRetryEntry *entry in _entries) {
        NSDate *candidate;
        if (_inFlight[entry.requestIdentifier] != nil) {
            NSDate *since = _inFlightSince[entry.requestIdentifier];
            candidate = since != nil ? [since dateByAddingTimeInterval:_policy.inFlightTimeout] : now;
        } else if ([self isEntryHeldUntilReadyLocked:entry]) {
            continue;
        } else {
            candidate = entry.nextAttemptDate;
        }
        if (earliest == nil || [candidate compare:earliest] == NSOrderedAscending) {
            earliest = candidate;
        }
    }
    if (earliest == nil) {
        _scheduledWakeDate = nil;
        _wakeGeneration++;
        return;
    }

    if (_scheduledWakeDate != nil && [_scheduledWakeDate compare:earliest] != NSOrderedDescending) {
        return;
    }

    NSTimeInterval delay = [earliest timeIntervalSinceDate:now];
    if (delay < 0) {
        delay = 0;
    }

    _scheduledWakeDate = earliest;
    NSUInteger generation = ++_wakeGeneration;
    __weak typeof(self) wSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), _serialQueue, ^{
        typeof(self) sSelf = wSelf;
        if (!sSelf) return;
        if (sSelf.wakeGeneration != generation) {
            return;
        }
        sSelf.scheduledWakeDate = nil;
        [sSelf flushLocked];
    });
}

/// The isolation boundary is the application, not the host: a mismatched host is a shard rotation and
/// is retargeted, not dropped. Fails open when either side of the comparison is unknown.
/// The verdict is inverted for a survivor — it names an application the device is leaving, so it goes
/// stale the moment the device is back in that application (replaying it would kill the live registration).
- (BOOL)isEntry:(PWRetryEntry *)entry staleForAppCode:(NSString *)currentAppCode applicationScoped:(BOOL)applicationScoped {
    id frozenApp = entry.requestDictionary[@"application"];
    NSString *frozenAppCode = [frozenApp isKindOfClass:[NSString class]] ? (NSString *)frozenApp : nil;
    if (frozenAppCode.length == 0 || currentAppCode.length == 0) {
        return NO;
    }
    if (entry.survivesApplicationChange) {
        return [frozenAppCode isEqualToString:currentAppCode];
    }
    return applicationScoped && ![frozenAppCode isEqualToString:currentAppCode];
}

/// The retarget is not persisted: the stored entry keeps the host it was enqueued for, and each
/// attempt is addressed to whatever host the application is reachable at when it is sent.
- (PWRetryEntry *)entryRetargetedToCurrentHost:(PWRetryEntry *)entry baseUrl:(NSString *)currentBaseUrl {
    if (entry.survivesApplicationChange || entry.pinsHost) {
        return entry;
    }
    if (entry.baseUrl.length == 0 || currentBaseUrl.length == 0 || [entry.baseUrl isEqualToString:currentBaseUrl]) {
        return entry;
    }

    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self
                       message:[NSString stringWithFormat:@"Replaying retry entry %@ against the current host of the same application", entry.methodName]];
    return [entry entryByRetargetingToBaseUrl:currentBaseUrl];
}

/// Not counted as an attempt: the readiness flush of the request manager sends the entry.
- (BOOL)isEntryHeldUntilReadyLocked:(PWRetryEntry *)entry {
    return entry.waitsForNetwork
        && [_transport respondsToSelector:@selector(isReadyForRetry)]
        && ![_transport isReadyForRetry];
}

- (void)wakeEntriesAwaitingNetworkLocked {
    NSDate *now = [NSDate date];
    BOOL woken = NO;
    for (PWRetryEntry *entry in [_entries copy]) {
        if (entry.awaitingNetwork) {
            [self replaceEntryLocked:[entry entryWokenAtDate:now]];
            woken = YES;
        }
    }
    if (woken) {
        [_storage saveEntries:_entries];
    }
}

/// Drops the oldest entries of `methodName` so that a new one fits within `limit`.
- (void)makeRoomForEntryOfMethodLocked:(NSString *)methodName limit:(NSUInteger)limit {
    NSIndexSet *matching = [_entries indexesOfObjectsPassingTest:^BOOL(PWRetryEntry *e, NSUInteger i, BOOL *stop) {
        return [e.methodName isEqualToString:methodName];
    }];
    if (matching.count < limit) {
        return;
    }
    NSUInteger excess = matching.count - limit + 1;
    NSMutableArray<NSString *> *oldest = [NSMutableArray arrayWithCapacity:excess];
    [matching enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [oldest addObject:self->_entries[idx].requestIdentifier];
        *stop = oldest.count == excess;
    }];
    for (NSString *identifier in oldest) {
        [self dropEntryLocked:identifier];
    }
    [PushwooshLog pushwooshLog:PW_LL_WARN className:self
                       message:[NSString stringWithFormat:@"Dropped %lu oldest queued %@ retries, at most %lu are kept", (unsigned long)excess, methodName, (unsigned long)limit]];
}

- (PWRetryEntry *)entryForIdentifierLocked:(NSString *)identifier {
    NSUInteger idx = [_entries indexOfObjectPassingTest:^BOOL(PWRetryEntry *e, NSUInteger i, BOOL *stop) {
        return [e.requestIdentifier isEqualToString:identifier];
    }];
    return idx == NSNotFound ? nil : _entries[idx];
}

- (void)clearInFlightLocked:(NSString *)identifier {
    [_inFlight removeObjectForKey:identifier];
    [_inFlightSince removeObjectForKey:identifier];
}

- (void)dropEntryLocked:(NSString *)identifier {
    [self clearInFlightLocked:identifier];
    [self removeEntryLocked:identifier];
}

- (void)removeEntryLocked:(NSString *)identifier {
    NSUInteger idx = [_entries indexOfObjectPassingTest:^BOOL(PWRetryEntry *e, NSUInteger i, BOOL *stop) {
        return [e.requestIdentifier isEqualToString:identifier];
    }];
    if (idx != NSNotFound) {
        [_entries removeObjectAtIndex:idx];
    }
}

- (void)replaceEntryLocked:(PWRetryEntry *)entry {
    NSUInteger idx = [_entries indexOfObjectPassingTest:^BOOL(PWRetryEntry *e, NSUInteger i, BOOL *stop) {
        return [e.requestIdentifier isEqualToString:entry.requestIdentifier];
    }];
    if (idx != NSNotFound) {
        _entries[idx] = entry;
    } else {
        [_entries addObject:entry];
    }
}

@end
