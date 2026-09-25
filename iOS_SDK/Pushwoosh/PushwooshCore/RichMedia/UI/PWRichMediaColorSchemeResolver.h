//
//  PWRichMediaColorSchemeResolver.h
//  PushwooshCore
//
//  Created by André Kis on 07.09.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#import <PushwooshCore/PWRichMediaTypes.h>

NS_ASSUME_NONNULL_BEGIN

/// Resolves the configured Rich Media color scheme (SDK-958) against the app at the moment of use.
/// Shared by the Rich Media web view and the native in-app dark overlay (SDK-971). For internal use.
@interface PWRichMediaColorSchemeResolver : NSObject

/// Interface style Rich Media content is presented with; applied to `overrideUserInterfaceStyle`.
+ (UIUserInterfaceStyle)resolvedInterfaceStyle;

/// `YES` when the configured scheme resolves to dark right now. Main thread only.
+ (BOOL)isCurrentSchemeDark;

@end

NS_ASSUME_NONNULL_END
#endif
