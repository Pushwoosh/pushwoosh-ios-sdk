//
//  PWPushPrimerPresenter.m
//  PushwooshCore
//
//  Created by André Kis on 15.06.2026.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS

#import "PWPushPrimerPresenter.h"
#import "PWPushPrimerViewController.h"
#import "PWInteractionDisabledWindow.h"
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PushwooshLog.h>

@implementation PWPushPrimerConfig
@end

static BOOL gPrimerOnScreen = NO;

@interface PWPushPrimerPresenter ()

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) PWPushPrimerPresenter *selfRetain;

@end

@implementation PWPushPrimerPresenter

- (void)presentWithConfig:(PWPushPrimerConfig *)config completion:(PWPushPrimerCompletion)completion {
    [self readAuthorizationStatusWithCompletion:^(UNAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleStatus:status config:config completion:completion];
        });
    }];
}

- (void)readAuthorizationStatusWithCompletion:(void (^)(UNAuthorizationStatus))completion {
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        completion(settings.authorizationStatus);
    }];
}

- (void)handleStatus:(UNAuthorizationStatus)status
              config:(PWPushPrimerConfig *)config
          completion:(PWPushPrimerCompletion)completion {
    if (status == UNAuthorizationStatusAuthorized || status == UNAuthorizationStatusProvisional) {
        [self report:PWPushPrimerOutcomeSuppressed completion:completion];
        return;
    }

    BOOL deniedState = (status == UNAuthorizationStatusDenied);
    if (deniedState && !config.fallbackToSettings) {
        [self report:PWPushPrimerOutcomeSuppressed completion:completion];
        return;
    }

    if (config.minInterval > 0) {
        NSTimeInterval lastShown = [[NSUserDefaults standardUserDefaults] doubleForKey:@"PWPushPrimerLastShownAt"];
        if (lastShown > 0 && ([[NSDate date] timeIntervalSince1970] - lastShown) < config.minInterval) {
            [self report:PWPushPrimerOutcomeSuppressed completion:completion];
            return;
        }
    }

    if (gPrimerOnScreen) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:@"Push primer already on screen, ignoring present call"];
        [self report:PWPushPrimerOutcomeSuppressed completion:completion];
        return;
    }

    UIWindow *window = [self makeWindow];
    if (window == nil) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:self
                           message:@"No scene or window available to present push primer"];
        [self report:PWPushPrimerOutcomeSuppressed completion:completion];
        return;
    }

    __weak typeof(self) weakSelf = self;
    void (^onAccept)(void) = ^{
        if (deniedState) {
            [weakSelf openSettings];
            [weakSelf dismissAndReport:PWPushPrimerOutcomeRedirectedToSettings completion:completion];
        } else {
            [[PWManagerBridge shared] registerForPushNotifications];
            [weakSelf dismissAndReport:PWPushPrimerOutcomeAccepted completion:completion];
        }
    };
    void (^onDecline)(void) = ^{
        [weakSelf dismissAndReport:PWPushPrimerOutcomeDeclined completion:completion];
    };
    void (^onPresentFailure)(void) = ^{
        [weakSelf dismissAndReport:PWPushPrimerOutcomeSuppressed completion:completion];
    };

    gPrimerOnScreen = YES;
    self.selfRetain = self;
    self.window = window;

    if (config.minInterval > 0) {
        [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"PWPushPrimerLastShownAt"];
    }

    if (config.style == PWPushPrimerStyleSheet) {
        [self presentSheetWithConfig:config window:window onAccept:onAccept onDecline:onDecline];
    } else {
        [self presentAlertWithConfig:config window:window onAccept:onAccept onDecline:onDecline onPresentFailure:onPresentFailure];
    }
}

- (void)presentAlertWithConfig:(PWPushPrimerConfig *)config
                        window:(UIWindow *)window
                      onAccept:(void (^)(void))onAccept
                     onDecline:(void (^)(void))onDecline
              onPresentFailure:(void (^)(void))onPresentFailure {
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor clearColor];
    window.rootViewController = root;
    [self attachWindowToScene:window];
    [window makeKeyAndVisible];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:config.title
                                                                  message:config.message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    NSString *acceptTitle = config.acceptButtonTitle ?: @"Allow";
    NSString *declineTitle = config.declineButtonTitle ?: @"Not now";

    [alert addAction:[UIAlertAction actionWithTitle:declineTitle
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
        onDecline();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:acceptTitle
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        onAccept();
    }]];

    [root presentViewController:alert animated:YES completion:^{
        if (root.presentedViewController == nil) {
            onPresentFailure();
        }
    }];
}

- (void)presentSheetWithConfig:(PWPushPrimerConfig *)config
                        window:(UIWindow *)window
                      onAccept:(void (^)(void))onAccept
                     onDecline:(void (^)(void))onDecline {
    PWPushPrimerViewController *vc = [[PWPushPrimerViewController alloc] initWithConfig:config
                                                                              onAccept:onAccept
                                                                             onDecline:onDecline];
    window.rootViewController = vc;
    [self attachWindowToScene:window];
    [window makeKeyAndVisible];
}

- (UIWindow *)makeWindow {
    CGRect bounds = [UIScreen mainScreen].bounds;
    PWInteractionDisabledWindow *window = [[PWInteractionDisabledWindow alloc] initWithFrame:bounds];
    window.windowLevel = UIWindowLevelAlert + 1;
    return window;
}

- (void)attachWindowToScene:(UIWindow *)window {
    Class sceneClass = NSClassFromString(@"UIWindowScene");
    if (sceneClass == nil) {
        return;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL scenesSelector = NSSelectorFromString(@"connectedScenes");
    SEL setWindowSceneSelector = NSSelectorFromString(@"setWindowScene:");
    NSSet *scenes = [(id)UIApplication.sharedApplication performSelector:scenesSelector];
    for (id scene in scenes) {
        if ([scene isKindOfClass:sceneClass]) {
            [window performSelector:setWindowSceneSelector withObject:scene];
            break;
        }
    }
#pragma clang diagnostic pop
}

- (void)openSettings {
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)dismissAndReport:(PWPushPrimerOutcome)outcome completion:(PWPushPrimerCompletion)completion {
    self.window.hidden = YES;
    self.window = nil;
    gPrimerOnScreen = NO;
    [self report:outcome completion:completion];
    self.selfRetain = nil;
}

- (void)report:(PWPushPrimerOutcome)outcome completion:(PWPushPrimerCompletion)completion {
    if (completion) {
        completion(outcome);
    }
}

@end

#endif
