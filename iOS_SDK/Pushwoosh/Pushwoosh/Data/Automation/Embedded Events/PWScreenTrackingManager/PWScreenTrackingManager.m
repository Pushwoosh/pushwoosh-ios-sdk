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

NSString * const defaultScreenOpenEvent = @"PW_ScreenOpen";
static NSString * const kScreenOpenedEvent = @"_ScreenOpened";
static NSTimeInterval const kScreenOpenedEventDelay = 0.1f;

static IMP pw_original_viewDidAppear_Imp;

@interface PWScreenTrackingManager ()

@property (nonatomic) BOOL trackingStarted;
@property (nonatomic) BOOL isWaitingToSendEvent;

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
    
    if (![self isKindOfClass:[UINavigationController class]] && ![self isKindOfClass:[UITabBarController class]]) {
        if (![PWScreenTrackingManager sharedManager].isWaitingToSendEvent) {
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kScreenOpenedEventDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    if ([PWScreenTrackingManager sharedManager].defaultScreenOpenAllowed) {
                        NSString *screenName = self.title.length > 0 ? self.title : self.navigationItem.title;
                        
                        if (!screenName) {
                            screenName = self.tabBarItem.title;
                        }
                        
                        if (!screenName) {
                            screenName = NSStringFromClass(self.class);
                        }
                        
                        NSDictionary *attrs = @{
                            @"device_type": @1,
                            @"screen_name": screenName,
                            @"application_version": [PWUtils appVersion],
                        };
                        
                        [[PWInAppManager sharedManager] postEvent:defaultScreenOpenEvent withAttributes:attrs];
                    }
                } @catch (NSException *exception) {
                    PWLogError(@"----------------------------------------------------");
                    PWLogError(@"PW_ScreenOpen exception: %@", exception);
                    PWLogError(@"----------------------------------------------------");
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

