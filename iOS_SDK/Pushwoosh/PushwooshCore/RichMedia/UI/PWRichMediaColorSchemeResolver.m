//
//  PWRichMediaColorSchemeResolver.m
//  PushwooshCore
//
//  Created by André Kis on 07.09.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS
#import "PWRichMediaColorSchemeResolver.h"
#import "PWInteractionDisabledWindow.h"
#import "PWConfig.h"

static NSString *PWRichMediaColorSchemeName(PWRichMediaColorScheme scheme) {
    switch (scheme) {
        case PWRichMediaColorSchemeSystem: return @"SYSTEM";
        case PWRichMediaColorSchemeLight: return @"LIGHT";
        case PWRichMediaColorSchemeDark: return @"DARK";
        case PWRichMediaColorSchemeApp:
        default: return @"APP";
    }
}

static NSString *PWInterfaceStyleName(UIUserInterfaceStyle style) {
    switch (style) {
        case UIUserInterfaceStyleDark: return @"dark";
        case UIUserInterfaceStyleLight: return @"light";
        default: return @"unspecified";
    }
}

@implementation PWRichMediaColorSchemeResolver

+ (UIUserInterfaceStyle)interfaceStyleForScheme:(PWRichMediaColorScheme)scheme
                                       hostStyle:(UIUserInterfaceStyle)hostStyle
                                     systemStyle:(UIUserInterfaceStyle)systemStyle {
    switch (scheme) {
        case PWRichMediaColorSchemeLight:
            return UIUserInterfaceStyleLight;
        case PWRichMediaColorSchemeDark:
            return UIUserInterfaceStyleDark;
        case PWRichMediaColorSchemeSystem:
            return systemStyle;
        case PWRichMediaColorSchemeApp:
        default:
            return hostStyle == UIUserInterfaceStyleUnspecified ? systemStyle : hostStyle;
    }
}

+ (NSArray<UIWindow *> *)candidateWindows {
    NSMutableArray<UIWindow *> *candidates = [NSMutableArray new];
    NSArray<NSNumber *> *activationStatePriority = @[@(UISceneActivationStateForegroundActive),
                                                     @(UISceneActivationStateForegroundInactive)];
    NSSet<UIScene *> *scenes = [UIApplication sharedApplication].connectedScenes;
    for (NSNumber *activationState in activationStatePriority) {
        for (UIScene *scene in scenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == activationState.integerValue) {
                [candidates addObjectsFromArray:((UIWindowScene *)scene).windows];
            }
        }
    }
    [candidates addObjectsFromArray:[UIApplication sharedApplication].windows];
    return candidates;
}

+ (UIWindow *)hostWindow {
    UIWindow *fallback = nil;
    for (UIWindow *window in [self candidateWindows]) {
        if (window.hidden || [window isKindOfClass:[PWInteractionDisabledWindow class]]) {
            continue;
        }
        if (window.isKeyWindow) {
            return window;
        }
        if (!fallback && window.rootViewController && window.windowLevel == UIWindowLevelNormal) {
            fallback = window;
        }
    }
    return fallback;
}

+ (UIViewController *)topViewControllerInWindow:(UIWindow *)window {
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

+ (UIViewController *)hostViewController {
    return [self topViewControllerInWindow:[self hostWindow]];
}

+ (UIUserInterfaceStyle)resolvedInterfaceStyle {
    PWRichMediaColorScheme scheme = [PWConfig config].richMediaColorScheme;
    UIWindow *window = [self hostWindow];
    UIViewController *host = [self topViewControllerInWindow:window];
    UITraitCollection *hostTraits = host ? host.traitCollection : window.traitCollection;
    UIUserInterfaceStyle hostStyle = hostTraits.userInterfaceStyle;
    UIUserInterfaceStyle systemStyle = [UIScreen mainScreen].traitCollection.userInterfaceStyle;
    UIUserInterfaceStyle resolved = [self interfaceStyleForScheme:scheme hostStyle:hostStyle systemStyle:systemStyle];

    [PushwooshLog pushwooshLog:PW_LL_DEBUG
                     className:self
                       message:[NSString stringWithFormat:@"colorScheme=%@ host=%@ style=%@",
                                PWRichMediaColorSchemeName(scheme),
                                host ? NSStringFromClass(host.class) : @"null",
                                PWInterfaceStyleName(resolved)]];
    return resolved;
}

+ (BOOL)isCurrentSchemeDark {
    return [self resolvedInterfaceStyle] == UIUserInterfaceStyleDark;
}

@end
#endif
