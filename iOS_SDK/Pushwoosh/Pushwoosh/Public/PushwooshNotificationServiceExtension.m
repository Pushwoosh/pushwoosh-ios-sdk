///
///  PushwooshNotificationServiceExtension.m
///  Pushwoosh SDK
///
///  Created by André Kis
///  Copyright © 2026 Pushwoosh. All rights reserved.
///

#import "PushwooshNotificationServiceExtension.h"

#if TARGET_OS_IOS

#import "PWNotificationServiceProcessor.h"
#import <PushwooshCore/PWConfig.h>

@interface PushwooshNotificationServiceExtension ()

/// didReceive… and serviceExtensionTimeWillExpire are both delivered on the main thread by the
/// system, and the per-request completion that prunes a finished processor is dispatched back to
/// the main queue too, so all access to this array stays on the main thread and needs no lock.
@property (nonatomic, strong) NSMutableArray<PWNotificationServiceProcessor *> *processors;

@end

@implementation PushwooshNotificationServiceExtension

- (instancetype)init {
    self = [super init];
    if (self) {
        _processors = [NSMutableArray array];
    }
    return self;
}

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request
                   withContentHandler:(void (^)(UNNotificationContent *))contentHandler {
    NSString *appGroupsName = [self pushwooshAppGroupsName];
    if (appGroupsName.length == 0) {
        appGroupsName = [[PWConfig config] appGroupsName];
    }

    __weak typeof(self) weakSelf = self;
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    __weak PWNotificationServiceProcessor *weakProcessor = processor;
    [processor armWithRequest:request
                    appGroups:appGroupsName
                   completion:^(UNNotificationContent *content) {
        contentHandler(content);
        [weakSelf.processors removeObjectIdenticalTo:weakProcessor];
    }];
    [self.processors addObject:processor];

    [self pushwooshPrepareForRequest:request completion:^{
        [processor process];
    }];
}

- (void)serviceExtensionTimeWillExpire {
    for (PWNotificationServiceProcessor *processor in [self.processors copy]) {
        [processor expireWithFallback];
    }
}

- (void)pushwooshPrepareForRequest:(UNNotificationRequest *)request
                        completion:(void (^)(void))completion {
    completion();
}

- (NSString *)pushwooshAppGroupsName {
    return nil;
}

@end

#endif
