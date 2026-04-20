//
//  PWScreenTrackingManager.m
//  Pushwoosh
//
//  Created by Fectum on 17/04/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWScreenTrackingManager.h"
#import <objc/runtime.h>
#import "PWInAppManager.h"
#import "PWUtils.h"
#import <PushwooshCore/PWManagerBridge.h>

NSString * const defaultScreenOpenEvent = @"PW_ScreenOpen";
static NSTimeInterval const kScreenOpenedEventDelay = 0.1f;

static IMP pw_original_viewDidAppear_Imp;

static BOOL pw_isSystemUIKitViewController(UIViewController *vc) {
    if (!vc) return YES;

    if ([vc isKindOfClass:[UINavigationController class]] ||
        [vc isKindOfClass:[UITabBarController class]] ||
        [vc isKindOfClass:[UIAlertController class]] ||
        [vc isKindOfClass:[UIInputViewController class]]) {
        return YES;
    }

    NSString *name = NSStringFromClass(vc.class);
    if ([name hasPrefix:@"_UI"] ||
        [name hasPrefix:@"UIInput"] ||
        [name hasPrefix:@"UICompatibility"] ||
        [name hasPrefix:@"UIKit"] ||
        [name hasPrefix:@"UIRemote"]) {
        return YES;
    }
    return NO;
}

static BOOL pw_isSwiftUIHostingController(UIViewController *vc) {
    NSString *name = NSStringFromClass(vc.class);
    return [name containsString:@"UIHostingController"];
}

static NSString *pw_displayNameForViewController(UIViewController *vc) {
    NSString *name = vc.title.length > 0 ? vc.title : vc.navigationItem.title;
    if (!name) {
        name = vc.tabBarItem.title;
    }
    if (!name) {
        name = pw_isSwiftUIHostingController(vc) ? @"SwiftUIRoot" : NSStringFromClass(vc.class);
    }
    return name;
}

static NSString *pw_screenNameForViewController(UIViewController *vc) {
    NSString *selfName = pw_displayNameForViewController(vc);

    UIViewController *parent = vc.parentViewController;
    if (parent && !pw_isSystemUIKitViewController(parent)) {
        NSString *parentName = pw_displayNameForViewController(parent);
        if (parentName.length > 0 && ![parentName isEqualToString:selfName]) {
            return [NSString stringWithFormat:@"%@/%@", parentName, selfName];
        }
    }
    return selfName;
}

@interface PWScreenTrackingManager ()

@property (nonatomic) BOOL trackingStarted;
@property (nonatomic) BOOL isWaitingToSendEvent;
@property (nonatomic, copy, readwrite) NSString *currentScreenName;

@end

@implementation PWScreenTrackingManager

+ (instancetype)sharedManager {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)setDefaultScreenOpenAllowed:(BOOL)defaultScreenOpenAllowed {
    _defaultScreenOpenAllowed = defaultScreenOpenAllowed;
    
    if (defaultScreenOpenAllowed) {
        [self startTracking];
    }
}

- (void)startTracking {
    if (!_trackingStarted) {
        _trackingStarted = YES;
        [self swizzle_viewDidAppear];
    }
}

void _replacement_viewDidAppear(UIViewController * self, SEL _cmd, BOOL animated) {
    ((void(*)(id,SEL,BOOL))pw_original_viewDidAppear_Imp)(self, _cmd, animated);

    if (!pw_isSystemUIKitViewController(self)) {
        if (![PWScreenTrackingManager sharedManager].isWaitingToSendEvent) {

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kScreenOpenedEventDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    NSString *screenName = pw_screenNameForViewController(self);

                    [PWScreenTrackingManager sharedManager].currentScreenName = screenName;

                    if ([PWScreenTrackingManager sharedManager].defaultScreenOpenAllowed) {
                        NSDictionary *attrs = @{
                            @"device_type": @1,
                            @"screen_name": screenName,
                            @"application_version": [PWUtils appVersion],
                        };

                        [[[PWManagerBridge shared] inAppManager] postEvent:defaultScreenOpenEvent withAttributes:attrs];
                    }
                } @catch (NSException *exception) {
                    [PushwooshLog pushwooshLog:PW_LL_ERROR
                                     className:self
                                       message:[NSString stringWithFormat:@"PW_ScreenOpen exception: %@", exception]];
                }

                [PWScreenTrackingManager sharedManager].isWaitingToSendEvent = NO;
            });
            
            [PWScreenTrackingManager sharedManager].isWaitingToSendEvent = YES;
        }
    }
}

- (void)swizzle_viewDidAppear {
    Method originalMethod = class_getInstanceMethod([UIViewController class], @selector(viewDidAppear:));
    pw_original_viewDidAppear_Imp = method_setImplementation(originalMethod, (IMP)_replacement_viewDidAppear);
}

@end

@implementation UIViewController (PWScreenTracking)

@end

