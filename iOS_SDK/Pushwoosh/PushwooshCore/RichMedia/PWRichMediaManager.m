//
//  PWRichMediaManager.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2018
//

#if TARGET_OS_IOS
#import "PWRichMediaManager.h"
#import <PushwooshCore/PWRichMedia.h>
#import <PushwooshCore/PWMessageViewController.h>
#import <PushwooshCore/PWModalWindow.h>
#import <PushwooshCore/PWModalWindowSettings.h>
#import "PWModalWindowConfiguration.h"
#import "PWConfig.h"
#import "PWRichMedia+Internal.h"
#import "PWResource.h"
#import "PWManagerBridge.h"
#import "PWInAppMessagesManager.h"

@implementation PWRichMediaManager

+ (instancetype)sharedManager {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
#if TARGET_OS_IPHONE
        _richMediaStyle = [PWRichMediaStyle new];
#endif
    }
    return self;
}

- (void)presentRichMedia:(PWRichMedia *)richMedia {
    if ([richMedia.resource hasNativeConfig]) {
        [[[PWManagerBridge shared] inAppMessagesManager] routeNativeInAppForResource:richMedia.resource
                                                                         messageHash:richMedia.pushPayload[@"p"]];
        return;
    }

    if (![self shouldPresentRichMedia:richMedia]) {
        return;
    }

    switch ([[PWConfig config] richMediaStyle]) {
        case PWRichMediaStyleTypeModal:
            [[PWModalWindowConfiguration shared] presentModalWindow:richMedia];
            break;
        case PWRichMediaStyleTypeLegacy:
        case PWRichMediaStyleTypeDefault:
            [PWMessageViewController presentWithRichMedia:richMedia];
            break;
        default:
            break;
    }

}

- (BOOL)shouldPresentRichMedia:(PWRichMedia *)richMedia {
    if ([self.delegate respondsToSelector:@selector(richMediaManager:shouldPresentRichMedia:)]) {
        return [self.delegate richMediaManager:self shouldPresentRichMedia:richMedia];
    }
    return YES;
}

@end
#endif
