///
///  PWNotificationExtensionManager.m
///  Pushwoosh
///
///  Created by Fectum on 05/07/2019.
///  Copyright © 2019 Pushwoosh. All rights reserved.
///

#import "PWNotificationExtensionManager.h"

#if TARGET_OS_IOS

#import "PWNotificationServiceProcessor.h"
#import <PushwooshCore/PWConfig.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation PWNotificationExtensionManager

+ (instancetype)sharedManager {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)handleNotificationRequest:(UNNotificationRequest *)request
                    withAppGroups:(NSString * _Nonnull)appGroupsName
                   contentHandler:(void (^ _Nonnull)(UNNotificationContent * _Nonnull))contentHandler {
    [self handleNotificationRequest:request appGroupsName:appGroupsName contentHandler:contentHandler];
}

- (void)handleNotificationRequest:(UNNotificationRequest *)request contentHandler:(void (^ _Nonnull)(UNNotificationContent * _Nonnull))contentHandler {
    [self handleNotificationRequest:request appGroupsName:[[PWConfig config] appGroupsName] contentHandler:contentHandler];
}

- (void)handleNotificationRequest:(UNNotificationRequest *)request
                    appGroupsName:(NSString *)appGroupsName
                   contentHandler:(void (^)(UNNotificationContent *))contentHandler {
    PWNotificationServiceProcessor *processor = [PWNotificationServiceProcessor new];
    [processor processRequest:request
                    appGroups:appGroupsName
                   completion:contentHandler];
}

@end

#pragma clang diagnostic pop

#else

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation PWNotificationExtensionManager

+ (instancetype)sharedManager {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)handleNotificationRequest:(UNNotificationRequest *)request
                    withAppGroups:(NSString * _Nonnull)appGroupsName
                   contentHandler:(void (^ _Nonnull)(UNNotificationContent * _Nonnull))contentHandler {
    contentHandler(request.content);
}

- (void)handleNotificationRequest:(UNNotificationRequest *)request contentHandler:(void (^ _Nonnull)(UNNotificationContent * _Nonnull))contentHandler {
    contentHandler(request.content);
}

@end

#pragma clang diagnostic pop

#endif
