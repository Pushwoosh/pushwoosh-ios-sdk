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

@interface PWMessageViewController : PWBaseLoadingViewController

+ (void)presentWithRichMedia:(PWRichMedia *)richMedia;

+ (void)presentWithRichMedia:(PWRichMedia *)richMedia completion:(void(^)(BOOL success))completion;

- (instancetype)initWithRichMedia:(PWRichMedia *)richMedia window:(UIWindow *)window richMediaStyle:(PWRichMediaStyle *)style completion:(void(^)(BOOL success))completion;

@end
#endif
