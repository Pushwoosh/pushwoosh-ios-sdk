//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#if TARGET_OS_IOS
#import <PushwooshCore/PWBaseLoadingViewController.h>
#import <PushwooshCore/PWResource.h>
#import <PushwooshCore/PWWebClient.h>

@class PWRichMedia;
@class PWRichMediaStyle;

/**
 Internal presenter for `legacy` / `default` rich media styles.

 The class methods below do NOT consult `PWRichMediaPresentingDelegate.shouldPresentRichMedia:`.
 The delegate gate lives one level up in `PWRichMediaManager.presentRichMedia:` —
 callers must route through that single entry point. Calling these methods directly
 will display rich media regardless of the delegate's decision.
 */
@interface PWMessageViewController : PWBaseLoadingViewController

/**
 Presents rich media in a `PWBaseLoadingViewController` flow. Skips presentation
 only when `richMedia.resource.locked` is YES. The delegate is not checked here.
 */
+ (void)presentWithRichMedia:(PWRichMedia *)richMedia;

/**
 Same as `presentWithRichMedia:`. Completion is invoked with `success=YES` after
 the view controller is presented; it is NOT invoked when presentation is skipped
 due to `richMedia.resource.locked`.
 */
+ (void)presentWithRichMedia:(PWRichMedia *)richMedia completion:(void(^)(BOOL success))completion;

- (instancetype)initWithRichMedia:(PWRichMedia *)richMedia window:(UIWindow *)window richMediaStyle:(PWRichMediaStyle *)style completion:(void(^)(BOOL success))completion;

@end
#endif
