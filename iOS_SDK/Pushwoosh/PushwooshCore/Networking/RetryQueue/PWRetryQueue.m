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
    NSString *identifier = request.requestIdentifier;
    PWRetryEntry *entry = [[PWRetryEntry alloc] initWithRequest:request now:[NSDate date]];

    __weak typeof(self) wSelf = self;
    dispatch_async(_serialQueue, ^{
        typeof(self) sSelf = wSelf;
        if (!sSelf) return;
        if ([sSelf entryForIdentifierLocked:identifier] != nil) {
            return;
        }
        [sSelf.entries addObject:entry];
        [sSelf.storage saveEntries:sSelf.entries];
        [sSelf flushLocked];
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

- (void)flushLocked {
    NSDate *now = [NSDate date];
    BOOL mutated = NO;

    for (PWRetryEntry *entry in [_entries copy]) {
        NSString *identifier = entry.requestIdentifier;

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
        __weak typeof(self) wSelf = self;
        [_transport sendRetryEntry:entry completion:^(NSInteger statusCode, NSError *error) {
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
