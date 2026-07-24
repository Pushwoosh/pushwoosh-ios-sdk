//
//  PWInAppHandler.h
//  PushwooshCore
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Canonical Obj-C declaration of the native in-app back-channel protocol. Mirrors
 the Swift `@objc public protocol PWInAppHandler` declared in `PushwooshBridge`.
 Same selectors — runtime dispatch resolves identically regardless of which side
 the handler instance was vended from.

 Core reads the in-app config from `native-config.json` inside a postEvent
 resource ZIP and forwards it through `handleInAppConfig:onShown:onClicked:onClosed:`;
 the module fires `onShown` when the message is actually displayed, `onClicked`
 when a URL action runs, and `onClosed` when the message is dismissed. Core maps
 the hooks to the same statistics as HTML rich media: show → triggerInAppAction,
 click/close → richMediaAction with action types 1/4. When the `PushwooshInApp`
 module is not linked the handler is `nil` and the call is a no-op.

 Visibility: project-only. Imported by Core consumers (`PWInAppMessagesManager`)
 and by unit tests.
 */
@protocol PWInAppHandler <NSObject>
- (void)handleInAppConfig:(NSDictionary *)config;
- (void)handleInAppConfig:(NSDictionary *)config onShown:(void (^ _Nullable)(void))onShown;
- (void)handleInAppConfig:(NSDictionary *)config
                  onShown:(void (^ _Nullable)(void))onShown
                onClicked:(void (^ _Nullable)(void))onClicked
                 onClosed:(void (^ _Nullable)(void))onClosed;
@end

NS_ASSUME_NONNULL_END
