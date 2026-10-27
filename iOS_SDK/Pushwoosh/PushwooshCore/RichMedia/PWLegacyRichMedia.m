//
//  PWLegacyRichMedia.m
//  PushwooshCore
//
//  Created by André Kis on 24.12.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS

#import "PWLegacyRichMedia.h"
#import "PWRichMediaManager.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation PWLegacyRichMedia

+ (Class<PWLegacyRichMedia>)legacyRichMedia {
    return self;
}

+ (id<PWRichMediaPresentingDelegate>)getDelegate {
    return [PWRichMediaManager sharedManager].delegate;
}

+ (void)setDelegate:(id<PWRichMediaPresentingDelegate>)delegate {
    [PWRichMediaManager sharedManager].delegate = delegate;
}

+ (PWRichMediaStyle *)getRichMediaStyle {
    return [PWRichMediaManager sharedManager].richMediaStyle ?: [PWRichMediaStyle new];
}

+ (void)setRichMediaStyle:(PWRichMediaStyle *)style {
    [PWRichMediaManager sharedManager].richMediaStyle = style ?: [PWRichMediaStyle new];
}

+ (void)presentRichMedia:(PWRichMedia *)richMedia {
    [[PWRichMediaManager sharedManager] presentRichMedia:richMedia];
}

@end

#pragma clang diagnostic pop

#endif
