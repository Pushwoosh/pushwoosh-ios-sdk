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
#import <PushwooshCore/PWRequest.h>
#import <PushwooshCore/PWPreferences.h>
#import <PushwooshCore/PushwooshLog.h>

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

    __weak typeof(self) wSelf = self;
    dispatch_async(_serialQueue, ^{
        typeof(self) sSelf = wSelf;
        if (!sSelf) return;
        if ([sSelf entryForIdentifierLocked:identifier] != nil) {
            return;
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
    [self flush];
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
    if (entry.survivesApplicationChange) {
        return entry;
    }
    if (entry.baseUrl.length == 0 || currentBaseUrl.length == 0 || [entry.baseUrl isEqualToString:currentBaseUrl]) {
        return entry;
    }

    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self
                       message:[NSString stringWithFormat:@"Replaying retry entry %@ against the current host of the same application", entry.methodName]];
    return [entry entryByRetargetingToBaseUrl:currentBaseUrl];
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
