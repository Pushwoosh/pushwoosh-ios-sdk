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

+ (void)presentRichMedia:(PWRichMedia *)richMedia {
    [[PWRichMediaManager sharedManager] presentRichMedia:richMedia];
}

@end

#endif
