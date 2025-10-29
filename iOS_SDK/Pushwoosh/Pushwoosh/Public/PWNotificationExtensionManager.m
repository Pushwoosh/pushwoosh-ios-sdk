//
//  PWNotificationExtensionManager.m
//  Pushwoosh
//
//  Created by Fectum on 05/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWNotificationExtensionManager.h"
#import <PushwooshCore/PWMessageDeliveryRequest.h>
#import <PushwooshCore/PWMessage+Internal.h>
#import <PushwooshCore/PWNetworkModule.h>
#import <PushwooshCore/NSDictionary+PWDictUtils.h>
#import <PushwooshCore/PWConfig.h>
#import <PushwooshCore/PushwooshLog.h>

@interface PWNotificationExtensionManager ()

// @Inject
@property (nonatomic, strong) PWRequestManager *requestManager;

@end

@implementation PWNotificationExtensionManager

+ (instancetype)sharedManager {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[PWNetworkModule module] inject:self];
    }
    return self;
}

- (void)handleNotificationRequest:(UNNotificationRequest *)request 
                    withAppGroups:(NSString * _Nonnull)appGroupsName
                   contentHandler:(void (^ _Nonnull)(UNNotificationContent * _Nonnull))contentHandler {
    UNMutableNotificationContent *bestAttemptContent = [request.content mutableCopy];
        
    NSString *group = [[PWConfig config] appGroupsName];
    if (group && ![group isEqualToString:@""])
        return;

    dispatch_group_t requestsGroup = dispatch_group_create();

    dispatch_group_enter(requestsGroup);
    [self setUpBadgesWithGroupsName:appGroupsName contentHadler:bestAttemptContent completion:^{
        dispatch_group_leave(requestsGroup);
    }];
    
    dispatch_group_notify(requestsGroup, dispatch_get_main_queue(), ^{
        contentHandler(bestAttemptContent);
    });
}

- (void)handleNotificationRequest:(UNNotificationRequest *)request contentHandler:(void (^ _Nonnull)(UNNotificationContent * _Nonnull))contentHandler {
#if TARGET_OS_IOS
    UNMutableNotificationContent *bestAttemptContent = [request.content mutableCopy];

    if (![PWMessage isPushwooshMessage:bestAttemptContent.userInfo]) {
        contentHandler(bestAttemptContent);
        return;
    }

    [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:[NSString stringWithFormat:@"Service notification extension was called with payload: %@", bestAttemptContent.userInfo]];
    
    NSString *appGroupsName = [[PWConfig config] appGroupsName];
        
    dispatch_group_t requestsGroup = dispatch_group_create();
    
    dispatch_group_enter(requestsGroup);
    [self setUpBadgesWithGroupsName:appGroupsName contentHadler:bestAttemptContent completion:^{
        dispatch_group_leave(requestsGroup);
    }];
    
    dispatch_group_enter(requestsGroup);
    [self sendDeliveryEventForPushNotification:bestAttemptContent.userInfo completion:^{
        dispatch_group_leave(requestsGroup);
    }];
    
    dispatch_group_enter(requestsGroup);
    [self downloadAttachmentForRequest:request bestAttemptContent:bestAttemptContent completion:^(NSError *error) {
        dispatch_group_leave(requestsGroup);
    }];

    dispatch_group_notify(requestsGroup, dispatch_get_main_queue(), ^{
        contentHandler(bestAttemptContent);
    });
#else
    // tvOS doesn't support userInfo property on UNNotificationContent
    contentHandler(request.content);
#endif
}

- (void)setUpBadgesWithGroupsName:(NSString *)appGroupsName
                    contentHadler:(UNMutableNotificationContent *)bestAttemptContent
                       completion:(dispatch_block_t)completion {
#if TARGET_OS_IOS
    NSString *key = @"badge_count";

    if (appGroupsName && ![appGroupsName isEqualToString:@""] && [appGroupsName isKindOfClass:[NSString class]]) {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:appGroupsName];
        NSInteger savedBadges = [defaults integerForKey:key];

        NSString *badges = [[[bestAttemptContent userInfo] pw_dictionaryForKey:@"aps"] pw_stringForKey:@"pw_badge"];
        NSString *sign = @"";
        
        if ([self isBadgeHasSign:badges]) {
            sign = [badges substringToIndex:1];
        }
        
        if ((badges && [sign isEqualToString:@""]) || (badges && savedBadges == 0 && [sign isEqualToString:@""])) {
            [defaults setInteger:[badges intValue] forKey:key];
            NSInteger count = [defaults integerForKey:key];
            bestAttemptContent.badge = @(count);
        }
        
        if (badges && [sign isEqualToString:@"+"]) {
            int receivedBadges = [[badges stringByReplacingOccurrencesOfString:@"+" withString:@""] intValue];
            NSInteger count = [defaults integerForKey:key];
            [defaults setInteger:(count + receivedBadges) forKey:key];
            bestAttemptContent.badge = @(count + receivedBadges);
        }
        
        if (badges && [sign isEqualToString:@"-"]) {
            if (savedBadges - [[badges substringFromIndex:1] integerValue] <= 0) {
                bestAttemptContent.badge = @0;
                [defaults setInteger:0 forKey:key];
            } else {
                int receivedBadges = [[badges stringByReplacingOccurrencesOfString:@"-" withString:@""] intValue];
                [defaults setInteger:(savedBadges - receivedBadges) forKey:key];
                bestAttemptContent.badge = @(savedBadges - receivedBadges);
            }
        }
    } else {
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:@"App Groups aren't installed"];
    }
#else
    // tvOS doesn't support userInfo property
#endif

    if (completion) {
        completion();
    }
}

- (void)sendDeliveryEventForPushNotification:(NSDictionary *)pushNotification completion:(dispatch_block_t)completion {
    PWMessageDeliveryRequest *request = [PWMessageDeliveryRequest new];
    request.pushDict = pushNotification;

    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (error) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"messageDeliveryEvent failed"];
        }

        if (completion) {
            completion();
        }
    }];
}

- (void)downloadAttachmentForRequest:(UNNotificationRequest *)request bestAttemptContent:(UNMutableNotificationContent *)bestAttemptContent completion:(void(^)(NSError *error))completion {
#if TARGET_OS_IOS
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
    
    [[[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            NSString *tempDict = NSTemporaryDirectory();
            NSString *attachmentID = [[[NSUUID UUID] UUIDString] stringByAppendingString:[response.URL.absoluteString lastPathComponent]];
            
            if(response.suggestedFilename) {
                attachmentID = [[[NSUUID UUID] UUIDString] stringByAppendingString:response.suggestedFilename];
            }
            
            NSString *tempFilePath = [tempDict stringByAppendingPathComponent:attachmentID];
            
            if ([[NSFileManager defaultManager] moveItemAtPath:location.path toPath:tempFilePath error:&error]) {
                UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:attachmentID URL:[NSURL fileURLWithPath:tempFilePath] options:nil error:&error];

                if (!attachment) {
                    [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"Create attachment error: %@", error]];
                } else {
                    bestAttemptContent.attachments = [bestAttemptContent.attachments arrayByAddingObject:attachment];
                }
            } else {
                [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"Move file error: %@", error]];
            }
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"Download file error: %@", error]];
        }
        
        if (completion) {
            completion(error);
        }
    }] resume];
#else
    // tvOS doesn't support userInfo and attachments
    if (completion) {
        completion(nil);
    }
#endif
}

- (BOOL)isBadgeHasSign:(NSString *)badges {
    return ([[badges substringToIndex:1] isEqualToString:@"+"] || [[badges substringToIndex:1] isEqualToString:@"-"]) ? YES : NO;
}

@end
