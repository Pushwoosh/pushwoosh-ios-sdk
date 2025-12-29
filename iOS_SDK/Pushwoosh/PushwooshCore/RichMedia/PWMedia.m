//
//  PWMedia.m
//  PushwooshCore
//
//  Created by André Kis on 24.12.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS

#import "PWMedia.h"
#import "PWConfig.h"
#import "PWModalRichMedia.h"
#import "PWLegacyRichMedia.h"

static NSString * const kPWRichMediaPresentationStyleKey = @"PWRichMediaPresentationStyle";

@implementation PWMedia

+ (Class<PWMedia>)media {
    return self;
}

+ (void)setRichMediaPresentationStyle:(PWRichMediaPresentationStyle)style {
    RichMediaStyleType configStyle;
    switch (style) {
        case PWRichMediaPresentationStyleModal:
            configStyle = PWRichMediaStyleTypeModal;
            break;
        case PWRichMediaPresentationStyleLegacy:
        default:
            configStyle = PWRichMediaStyleTypeLegacy;
            break;
    }
    [PWConfig config].richMediaStyle = configStyle;
    [[NSUserDefaults standardUserDefaults] setInteger:style forKey:kPWRichMediaPresentationStyleKey];
}

+ (PWRichMediaPresentationStyle)richMediaPresentationStyle {
    switch ([[PWConfig config] richMediaStyle]) {
        case PWRichMediaStyleTypeModal:
            return PWRichMediaPresentationStyleModal;
        case PWRichMediaStyleTypeLegacy:
        case PWRichMediaStyleTypeDefault:
        default:
            return PWRichMediaPresentationStyleLegacy;
    }
}

+ (Class<PWModalRichMedia>)modalRichMedia {
    return [PWModalRichMedia class];
}

+ (Class<PWLegacyRichMedia>)legacyRichMedia {
    return [PWLegacyRichMedia class];
}

@end

#endif
