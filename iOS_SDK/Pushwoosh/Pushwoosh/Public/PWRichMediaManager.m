//
//  PWInAppManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2018
//

#if TARGET_OS_IOS
#import "PWRichMediaManager.h"
#import "PWRichMedia+Internal.h"
#import "PWMessageViewController.h"
#import "PWModalWindow.h"
#import "PWModalWindowSettings.h"
#import "PWModalWindowConfiguration.h"
#import "PWConfig.h"

@implementation PWRichMedia

- (instancetype)initWithSource:(PWRichMediaSource)source resource:(PWResource *)resource {
    return [self initWithSource:source resource:resource pushPayload:nil];
}

- (instancetype)initWithSource:(PWRichMediaSource)source resource:(PWResource *)resource pushPayload:(NSDictionary *)pushPayload {
    self = [super init];
    
    if (self) {
        _source = source;
        _resource = resource;
        _pushPayload = pushPayload;
    }
    
    return self;
}

- (NSString *)content {
    return _resource.code;
}

- (BOOL)isRequired {
    return _source == PWRichMediaSourceInApp ? _resource.required : YES;
}

@end

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
