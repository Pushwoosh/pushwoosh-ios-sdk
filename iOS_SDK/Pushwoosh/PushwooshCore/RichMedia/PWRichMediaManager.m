//
//  PWInAppManager.h
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

@end
#endif
