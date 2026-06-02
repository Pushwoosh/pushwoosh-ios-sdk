/*
 *  PushwooshModuleRegistry.m
 *  PushwooshCore
 *
 *  Created by André Kis on 21.05.26.
 *  Copyright © 2026 Pushwoosh. All rights reserved.
 */

#import "PushwooshModuleRegistry.h"
#import "PWMissingModule.h"

@implementation PushwooshModuleRegistry

static NSMutableDictionary<NSString *, Class> *_classes;
static NSMutableDictionary<NSString *, id> *_handlers;
static dispatch_queue_t _queue;

/// `_queue`, `_classes`, and `_handlers` are initialised lazily in
/// `+initialize`. Do NOT move this initialisation into `+load`:
/// `+load` ordering across module images is undefined per dyld, and any
/// `<Module>Loader.m +load` may call `registerClass:` / `registerHandler:`
/// before this class's own `+load` has run. The Objective-C runtime
/// guarantees that `+initialize` fires before the first message send to a
/// class, so deferring init here is the only safe pattern for a class that
/// receives messages from foreign `+load` methods.
+ (void)initialize {
    if (self == [PushwooshModuleRegistry class]) {
        _classes = [NSMutableDictionary new];
        _handlers = [NSMutableDictionary new];
        _queue = dispatch_queue_create("com.pushwoosh.moduleRegistry", DISPATCH_QUEUE_CONCURRENT);
    }
}

+ (void)registerClass:(Class)cls forIdentifier:(PushwooshModuleIdentifier)identifier {
    if (cls == Nil || identifier.length == 0) {
        return;
    }
    NSString *key = [identifier copy];
    dispatch_barrier_sync(_queue, ^{
        _classes[key] = cls;
    });
}

+ (void)registerHandler:(id)handler forIdentifier:(PushwooshModuleIdentifier)identifier {
    if (handler == nil || identifier.length == 0) {
        return;
    }
    NSString *key = [identifier copy];
    dispatch_barrier_sync(_queue, ^{
        _handlers[key] = handler;
    });
}

+ (Class)classForIdentifier:(PushwooshModuleIdentifier)identifier {
    __block Class result = Nil;
    dispatch_sync(_queue, ^{
        result = _classes[identifier];
    });
    return result ?: [PWMissingModule class];
}

+ (id)handlerForIdentifier:(PushwooshModuleIdentifier)identifier {
    __block id result = nil;
    dispatch_sync(_queue, ^{
        result = _handlers[identifier];
    });
    return result;
}

+ (void)_resetForTesting {
    dispatch_barrier_sync(_queue, ^{
        [_classes removeAllObjects];
        [_handlers removeAllObjects];
    });
}

@end
