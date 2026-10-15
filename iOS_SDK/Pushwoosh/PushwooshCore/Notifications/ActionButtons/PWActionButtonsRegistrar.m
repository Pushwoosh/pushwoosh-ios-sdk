//
//  PWActionButtonsRegistrar.m
//  PushwooshCore
//
//  Created by André Kis on 08.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWActionButtonsRegistrar.h"

#if TARGET_OS_IOS

static NSString * const kPWActionButtonsRecentCategoriesKey = @"PWActionButtonCategories";

/// Registrations are serialized process-wide, since the centre has no atomic category update; a waiter
/// that times out proceeds unserialized rather than stranding its push.
static const int64_t kPWActionButtonsGateTimeout = NSEC_PER_SEC / 2;

static dispatch_semaphore_t PWActionButtonsGate(void) {
    static dispatch_semaphore_t gate;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gate = dispatch_semaphore_create(1);
    });
    return gate;
}

/// Waiting parks a thread, so it is parked here and never on a queue a caller needs back.
static dispatch_queue_t PWActionButtonsGateQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("com.pushwoosh.actionbuttons.gate", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

/// Runs section once the gate is free or the wait expires; the flag says whether it has to be given back.
static void PWActionButtonsGateEnter(void (^section)(BOOL held)) {
    dispatch_async(PWActionButtonsGateQueue(), ^{
        long waited = dispatch_semaphore_wait(PWActionButtonsGate(), dispatch_time(DISPATCH_TIME_NOW, kPWActionButtonsGateTimeout));
        section(waited == 0);
    });
}

static void PWActionButtonsGateLeave(BOOL held) {
    if (held) {
        dispatch_semaphore_signal(PWActionButtonsGate());
    }
}

@interface PWActionButtonsRegistrar ()

@property (nonatomic, strong) UNUserNotificationCenter *center;
@property (nonatomic, strong) NSUserDefaults *defaults;

@end

@implementation PWActionButtonsRegistrar

- (instancetype)init {
    return [self initWithNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
                                    defaults:[NSUserDefaults standardUserDefaults]];
}

- (instancetype)initWithNotificationCenter:(UNUserNotificationCenter *)center defaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) {
        _center = center;
        _defaults = defaults;
    }
    return self;
}

+ (NSString *)categoryIdentifierForButtons:(NSArray<PWActionButton *> *)buttons {
    NSMutableString *canonical = [NSMutableString string];
    for (PWActionButton *button in buttons) {
        [canonical appendFormat:@"%@\x01%@\x01%ld\x01%@\x01%d\x02",
         button.identifier, button.label, (long)button.action, button.url ?: @"", button.destructive];
    }

    return [PWActionButtonsCategoryPrefix stringByAppendingString:[self fnv1aHexOf:canonical]];
}

+ (UNNotificationCategory *)categoryForButtons:(NSArray<PWActionButton *> *)buttons {
    NSMutableArray<UNNotificationAction *> *actions = [NSMutableArray array];

    for (PWActionButton *button in buttons) {
        UNNotificationActionOptions options = UNNotificationActionOptionNone;
        if (button.opensApplication) {
            options |= UNNotificationActionOptionForeground;
        }
        if (button.destructive) {
            options |= UNNotificationActionOptionDestructive;
        }

        [actions addObject:[UNNotificationAction actionWithIdentifier:button.identifier
                                                                  title:button.label
                                                                options:options]];
    }

    return [UNNotificationCategory categoryWithIdentifier:[self categoryIdentifierForButtons:buttons]
                                                    actions:actions
                                          intentIdentifiers:@[]
                                                    options:UNNotificationCategoryOptionNone];
}

- (void)registerCategoryForButtons:(NSArray<PWActionButton *> *)buttons completion:(void (^)(void))completion {
    if (buttons.count == 0) {
        if (completion) {
            completion();
        }
        return;
    }

    UNNotificationCategory *category = [[self class] categoryForButtons:buttons];
    __weak typeof(self) weakSelf = self;

    PWActionButtonsGateEnter(^(BOOL held) {
        __block BOOL answered = NO;
        /// The gate is given back from inside the once-guard, so neither a lost nor a doubled answer strands it.
        void (^answer)(void) = ^{
            if (answered) {
                return;
            }
            answered = YES;
            PWActionButtonsGateLeave(held);
            if (completion) {
                completion();
            }
        };

        PWActionButtonsRegistrar *registrar = weakSelf;
        if (registrar == nil) {
            answer();
            return;
        }

        NSSet<NSString *> *retired = [registrar rememberCategoryIdentifier:category.identifier];

        [registrar.center getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *existing) {
            PWActionButtonsRegistrar *current = weakSelf;
            if (current == nil) {
                answer();
                return;
            }

            NSMutableSet<UNNotificationCategory *> *merged = [NSMutableSet set];

            for (UNNotificationCategory *registered in existing) {
                if ([registered.identifier isEqualToString:category.identifier]) {
                    continue;
                }
                if ([retired containsObject:registered.identifier]) {
                    continue;
                }
                [merged addObject:registered];
            }

            [merged addObject:category];
            [current.center setNotificationCategories:merged];

            /// setNotificationCategories: only hands the set to the daemon; the read-back is what proves it landed.
            [current.center getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *applied) {
                answer();
            }];
        }];
    });
}

/// Most recently registered last. Returns the identifiers this SDK registered itself and has now
/// dropped — the only ones eviction may remove, so a foreign pw_ category is never touched.
- (NSSet<NSString *> *)rememberCategoryIdentifier:(NSString *)identifier {
    NSMutableArray<NSString *> *recent = [[_defaults stringArrayForKey:kPWActionButtonsRecentCategoriesKey] mutableCopy] ?: [NSMutableArray array];

    [recent removeObject:identifier];
    [recent addObject:identifier];

    NSMutableSet<NSString *> *retired = [NSMutableSet set];
    if (recent.count > PWActionButtonsCategoryLimit) {
        NSRange dropped = NSMakeRange(0, recent.count - PWActionButtonsCategoryLimit);
        [retired addObjectsFromArray:[recent subarrayWithRange:dropped]];
        [recent removeObjectsInRange:dropped];
    }

    [_defaults setObject:recent forKey:kPWActionButtonsRecentCategoriesKey];

    return retired;
}

+ (NSString *)fnv1aHexOf:(NSString *)string {
    uint64_t hash = 14695981039346656037ull;
    NSData *bytes = [string dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    const uint8_t *cursor = bytes.bytes;

    for (NSUInteger index = 0; index < bytes.length; index++) {
        hash ^= cursor[index];
        hash *= 1099511628211ull;
    }

    return [NSString stringWithFormat:@"%016llx", hash];
}

@end

#endif
