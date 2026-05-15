#if TARGET_OS_IOS

//
//  PWModalWindow.h
//  Pushwoosh
//
//  Created by Andrei Kiselev on 10.2.23..
//  Copyright © 2023 Pushwoosh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PushwooshCore/PWResource.h>
#import <PushwooshCore/PWRichMediaView.h>
#import <PushwooshCore/PWModalWindowConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Internal modal container view for rich media presentation.

 The methods below do NOT consult `PWRichMediaPresentingDelegate.shouldPresentRichMedia:`.
 The delegate gate lives one level up in `PWRichMediaManager.presentRichMedia:` — callers
 must route through that single entry point. Calling these methods directly will display
 rich media regardless of the delegate's decision.
 */
@interface PWModalWindow : UIView

@property (nonatomic) UIButton *closeButton;

- (void)closeModalWindowAfter:(NSTimeInterval)interval;

/**
 Attaches a new modal container to the key window and starts the rich media lifecycle.
 Invoked from `PWModalWindowConfiguration.presentModalWindow:`. Assumes the delegate
 gate already approved the presentation upstream.
 */
- (void)presentModalWindow:(PWRichMedia *)richMedia modalWindow:(PWModalWindow *)modalWindow;

/**
 Loads the `PWRichMediaView` into the container and animates it on screen.
 Skips presentation only when `richMedia.resource.locked` is YES. The delegate
 `shouldPresentRichMedia:` is not checked here.
 */
- (void)createModalWindow:(PWResource *)resource modalWindow:(PWRichMedia *)richMedia;

/**
 Sets up the modal container (adds it to `window`, configures the close button and
 layout constraints) and triggers `createModalWindow:modalWindow:`. The delegate
 `shouldPresentRichMedia:` is not checked here.
 */
- (void)createModalWindowWith:(PWResource *)resource
                    richMedia:(PWRichMedia *)richMedia
                  modalWindow:(PWModalWindow *)modalWindow
                       window:(UIWindow *)window;

@end

NS_ASSUME_NONNULL_END

#endif
