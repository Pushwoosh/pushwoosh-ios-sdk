//
//  PWRichMediaManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2018
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS

#import <PushwooshCore/PWRichMediaStyle.h>

#endif

@class PWRichMedia;
@class PWRichMediaManager;

/**
 Interface for Rich Media presentation managing.
 */
@protocol PWRichMediaPresentingDelegate <NSObject>

@optional

/**
 Checks the delegate whether the Rich Media should be displayed.
 */
- (BOOL)richMediaManager:(PWRichMediaManager *)richMediaManager shouldPresentRichMedia:(PWRichMedia *)richMedia;

/**
 Tells the delegate that Rich Media has been displayed.
 */
- (void)richMediaManager:(PWRichMediaManager *)richMediaManager didPresentRichMedia:(PWRichMedia *)richMedia;

/**
 Tells the delegate that Rich Media has been closed.
 */
- (void)richMediaManager:(PWRichMediaManager *)richMediaManager didCloseRichMedia:(PWRichMedia *)richMedia;

/**
 Tells the delegate that an error occurred while presenting Rich Media.
 */
- (void)richMediaManager:(PWRichMediaManager *)richMediaManager presentingDidFailForRichMedia:(PWRichMedia *)richMedia withError:(NSError *)error;

@end


/**
 `PWRichMediaManager` is the singleton entry point for all rich media presentation.

 ## Single delegate-gate invariant

 `presentRichMedia:` is the only place where `PWRichMediaPresentingDelegate.shouldPresentRichMedia:`
 is checked. All upstream paths — push (`PWInAppMessagesManager.presentRichMediaFromPush:`),
 postEvent (`PWInAppMessagesManager.postEvent:`), and the public manual APIs
 (`PWModalRichMedia.presentRichMedia:`, `PWLegacyRichMedia.presentRichMedia:`) — must
 route through this method. Downstream classes (`PWModalWindow`, `PWMessageViewController`,
 `PWModalWindowConfiguration`) do NOT re-check the delegate; they assume the gate
 already approved the presentation.

 Exception: native in-app resources (`native-config.json` in the ZIP) are routed to the
 `PushwooshInApp` module at the top of `presentRichMedia:`, BEFORE the gate, and are
 intentionally NOT subject to `shouldPresentRichMedia:` — they carry their own lifecycle
 callbacks (onShown/onClicked/onClosed). The gate governs HTML / modal rich media only.
 */
@interface PWRichMediaManager : NSObject

#if TARGET_OS_IOS

/**
 Style for Rich Media presenting.
 */
@property (nonatomic) PWRichMediaStyle *richMediaStyle;

#endif

/**
 Delegate for Rich Media presentation managing.
 */
@property (nonatomic) id<PWRichMediaPresentingDelegate> delegate;

/**
 A singleton object that represents the rich media manager.
 */
+ (instancetype)sharedManager;

/**
 Presents the rich media object. Must be called on the main thread.
 Skips presentation when the delegate's
 richMediaManager:shouldPresentRichMedia: returns NO. Native in-app resources
 (native-config.json) are routed to the PushwooshInApp module before this gate and
 bypass the delegate (see the single delegate-gate invariant above).
 */
- (void)presentRichMedia:(PWRichMedia *)richMedia;

@end

