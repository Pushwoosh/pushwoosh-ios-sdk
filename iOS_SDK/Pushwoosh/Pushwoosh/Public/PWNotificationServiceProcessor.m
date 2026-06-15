///
///  PWNotificationServiceProcessor.m
///  Pushwoosh SDK
///
///  Created by André Kis
///  Copyright © 2026 Pushwoosh. All rights reserved.
///

#import "PWNotificationServiceProcessor.h"

#if TARGET_OS_IOS

#import <sys/file.h>
#import <errno.h>

#import <PushwooshCore/PWMessageDeliveryRequest.h>
#import <PushwooshCore/PWMessage+Internal.h>
#import <PushwooshCore/PWNetworkModule.h>
#import <PushwooshCore/NSDictionary+PWDictUtils.h>
#import <PushwooshCore/PushwooshLog.h>

@interface PWNotificationServiceProcessor ()

@property (nonatomic, strong) PWRequestManager *requestManager;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong, nullable) UNNotificationRequest *request;
@property (nonatomic, copy, nullable) NSString *appGroupsName;
@property (nonatomic, strong, nullable) UNMutableNotificationContent *bestAttemptContent;
@property (nonatomic, strong, nullable) UNNotificationContent *originalContent;
@property (nonatomic, copy, nullable) void (^completion)(UNNotificationContent *);
@property (nonatomic, assign) BOOL consumed;
@property (nonatomic, assign) BOOL started;

@end

@implementation PWNotificationServiceProcessor

- (instancetype)init {
    self = [super init];
    if (self) {
        _serialQueue = dispatch_queue_create("com.pushwoosh.nse.processor", DISPATCH_QUEUE_SERIAL);
        [[PWNetworkModule module] inject:self];
    }
    return self;
}

- (void)armWithRequest:(UNNotificationRequest *)request
             appGroups:(NSString *)appGroupsName
            completion:(void (^)(UNNotificationContent *))completion {
    self.consumed = NO;
    self.started = NO;
    self.request = request;
    self.appGroupsName = appGroupsName;
    self.originalContent = request.content;
    self.bestAttemptContent = [request.content mutableCopy];
    self.completion = completion;
}

- (void)processRequest:(UNNotificationRequest *)request
             appGroups:(NSString *)appGroupsName
            completion:(void (^)(UNNotificationContent *))completion {
    [self armWithRequest:request appGroups:appGroupsName completion:completion];
    [self process];
}

/// Invoked exactly once per request, from the prepare-completion hook, so the `started` guard has
/// no concurrent writer and needs no synchronization regardless of which thread the hook completes
/// on. All real work is dispatched onto serialQueue, so the calling thread doesn't matter.
- (void)process {
    if (self.started) {
        return;
    }
    self.started = YES;

    UNNotificationRequest *request = self.request;
    NSString *appGroupsName = self.appGroupsName;
    UNMutableNotificationContent *content = self.bestAttemptContent;

    if (![PWMessage isPushwooshMessage:content.userInfo]) {
        dispatch_async(self.serialQueue, ^{
            [self finalizeOnQueue];
        });
        return;
    }

    [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:[NSString stringWithFormat:@"Notification service extension was called with payload: %@", content.userInfo]];

    dispatch_group_t requestsGroup = dispatch_group_create();

    dispatch_group_enter(requestsGroup);
    [self setUpBadgesWithGroupsName:appGroupsName content:content completion:^{
        dispatch_group_leave(requestsGroup);
    }];

    dispatch_group_enter(requestsGroup);
    [self sendDeliveryEventForPushNotification:content.userInfo completion:^{
        dispatch_group_leave(requestsGroup);
    }];

    dispatch_group_enter(requestsGroup);
    [self downloadAttachmentForRequest:request content:content completion:^(NSError *error) {
        dispatch_group_leave(requestsGroup);
    }];

    dispatch_group_notify(requestsGroup, self.serialQueue, ^{
        [self finalizeOnQueue];
    });
}

- (void)finalizeOnQueue {
    [self consumeOnQueue];
}

- (void)expireWithFallback {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.serialQueue, ^{
        [weakSelf consumeOnQueue];
    });
}

- (void)consumeOnQueue {
    if (self.consumed) {
        return;
    }
    self.consumed = YES;

    UNNotificationContent *content = self.bestAttemptContent ?: self.originalContent;
    void (^complete)(UNNotificationContent *) = self.completion;
    self.completion = nil;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (complete && content) {
            complete(content);
        }
    });
}

#pragma mark - Processing

/// Computes the new badge value and hops the blocking flock + NSUserDefaults read-modify-write OFF
/// the serial queue onto a global queue, so the serial queue stays free for finalizeOnQueue /
/// expireWithFallback — the timeout fallback must never be queued behind a blocking syscall. The
/// resulting badge value is hopped back onto the serial queue (ordering vs finalize) and the
/// dispatch group is left only after that hop.
- (void)setUpBadgesWithGroupsName:(NSString *)appGroupsName
                          content:(UNMutableNotificationContent *)content
                       completion:(dispatch_block_t)completion {
    if (![appGroupsName isKindOfClass:[NSString class]] || appGroupsName.length == 0) {
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:@"App Groups aren't installed"];
        if (completion) {
            completion();
        }
        return;
    }

    NSString *badges = [[[content userInfo] pw_dictionaryForKey:@"aps"] pw_forceStringForKey:@"pw_badge"];

    if (!badges) {
        if (completion) {
            completion();
        }
        return;
    }

    NSString *sign = [self isBadgeHasSign:badges] ? [badges substringToIndex:1] : @"";
    NSInteger amount = [(sign.length > 0 ? [badges substringFromIndex:1] : badges) integerValue];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *key = @"badge_count";
        __block NSInteger newBadge = amount;

        [self withBadgeLockForGroup:appGroupsName perform:^(NSUserDefaults *defaults) {
            NSInteger savedBadges = [defaults integerForKey:key];

            if ([sign isEqualToString:@"+"]) {
                newBadge = savedBadges + amount;
            } else if ([sign isEqualToString:@"-"]) {
                newBadge = MAX(savedBadges - amount, 0);
            } else {
                newBadge = amount;
            }

            [defaults setInteger:newBadge forKey:key];
        }];

        dispatch_async(self.serialQueue, ^{
            content.badge = @(newBadge);
            if (completion) {
                completion();
            }
        });
    });
}

/// Runs the badge read-modify-write inside an flock(LOCK_EX) advisory lock on a file in the App-Group
/// container, serializing it across threads AND processes (concurrent NSE instances). A fresh fd per
/// acquisition is required so flock mutually excludes; degrades to no lock when no real container is
/// entitled. Caveat: cfprefsd may cache the suite in-process, so the fresh suite read is best-effort.
- (void)withBadgeLockForGroup:(NSString *)appGroupsName perform:(void (^)(NSUserDefaults *defaults))block {
    if (!block) {
        return;
    }

    NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:appGroupsName];

    if (containerURL == nil) {
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:[NSString stringWithFormat:@"App Group \"%@\" container is unavailable; badge count is updated without a cross-process lock. Check the App Group capability on the extension target.", appGroupsName]];
        block([[NSUserDefaults alloc] initWithSuiteName:appGroupsName]);
        return;
    }

    NSString *lockPath = [[containerURL URLByAppendingPathComponent:@"pw_badge.lock"] path];
    int fd;
    do {
        fd = open([lockPath fileSystemRepresentation], O_CREAT | O_RDWR, 0644);
    } while (fd == -1 && errno == EINTR);

    if (fd == -1) {
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:[NSString stringWithFormat:@"Could not open the badge lock file (errno %d); badge count is updated without a cross-process lock.", errno]];
        block([[NSUserDefaults alloc] initWithSuiteName:appGroupsName]);
        return;
    }

    int locked;
    do {
        locked = flock(fd, LOCK_EX);
    } while (locked == -1 && errno == EINTR);

    if (locked == -1) {
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:[NSString stringWithFormat:@"Could not acquire the badge lock (errno %d); badge count is updated without a cross-process lock.", errno]];
    }

    @try {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:appGroupsName];
        block(defaults);
        [defaults synchronize];
    } @finally {
        flock(fd, LOCK_UN);
        close(fd);
    }
}

- (void)sendDeliveryEventForPushNotification:(NSDictionary *)pushNotification completion:(dispatch_block_t)completion {
    if (_requestManager == nil) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:@"messageDeliveryEvent skipped: request manager is not available"];
        if (completion) {
            completion();
        }
        return;
    }

    [_requestManager loadReverseProxyFromAppGroups:self.appGroupsName];

    PWMessageDeliveryRequest *request = [PWMessageDeliveryRequest new];
    request.pushDict = pushNotification;

    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (error) {
            [PushwooshLog pushwooshLog:PW_LL_WARN
                             className:self
                               message:[NSString stringWithFormat:@"messageDeliveryEvent not delivered (will retry if transient): %@", error.localizedDescription]];
        }

        if (completion) {
            completion();
        }
    }];
}

- (void)downloadAttachmentForRequest:(UNNotificationRequest *)request
                             content:(UNMutableNotificationContent *)content
                          completion:(void (^)(NSError *error))completion {
    NSString *attachmentUrlString = [request.content.userInfo objectForKey:@"attachment"];

    if (![attachmentUrlString isKindOfClass:[NSString class]]) {
        if (completion) {
            completion(nil);
        }
        return;
    }

    NSURL *url = [NSURL URLWithString:attachmentUrlString];

    if (!url) {
        if (completion) {
            completion(nil);
        }
        return;
    }

    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                completion(error);
            }
            return;
        }
        if (!error) {
            NSString *tempDir = NSTemporaryDirectory();
            NSString *suggestedName = response.suggestedFilename ?: [response.URL.absoluteString lastPathComponent];
            NSString *attachmentID = [[[NSUUID UUID] UUIDString] stringByAppendingString:[strongSelf sanitizedFileNameComponent:suggestedName]];

            NSString *tempFilePath = [tempDir stringByAppendingPathComponent:attachmentID];

            if ([[NSFileManager defaultManager] moveItemAtPath:location.path toPath:tempFilePath error:&error]) {
                UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:attachmentID URL:[NSURL fileURLWithPath:tempFilePath] options:nil error:&error];

                if (!attachment) {
                    [PushwooshLog pushwooshLog:PW_LL_ERROR className:strongSelf message:[NSString stringWithFormat:@"Create attachment error: %@", error]];
                } else {
                    dispatch_async(strongSelf.serialQueue, ^{
                        content.attachments = [content.attachments arrayByAddingObject:attachment];
                    });
                }
            } else {
                [PushwooshLog pushwooshLog:PW_LL_ERROR className:strongSelf message:[NSString stringWithFormat:@"Move file error: %@", error]];
            }
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:strongSelf message:[NSString stringWithFormat:@"Download file error: %@", error]];
        }

        if (completion) {
            completion(error);
        }
    }] resume];
}

- (NSString *)sanitizedFileNameComponent:(NSString *)name {
    if (![name isKindOfClass:[NSString class]] || name.length == 0) {
        return @"";
    }

    NSString *lastComponent = [name lastPathComponent];
    NSString *cleaned = [lastComponent stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@".." withString:@"_"];

    return cleaned;
}

- (BOOL)isBadgeHasSign:(NSString *)badges {
    if (badges.length < 1) {
        return NO;
    }

    NSString *sign = [badges substringToIndex:1];
    return [sign isEqualToString:@"+"] || [sign isEqualToString:@"-"];
}

@end

#endif
