//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PWBaseLoadingViewController.h"
#import "PWResource.h"
#import "PWWebClient.h"
#import "PWRichMediaManager.h"
#import "PWInAppManager.h"

@interface PWMessageViewController : PWBaseLoadingViewController

+ (void)presentWithRichMedia:(PWRichMedia *)richMedia;

+ (void)presentWithRichMedia:(PWRichMedia *)richMedia completion:(void(^)(BOOL success))completion;

- (instancetype)initWithRichMedia:(PWRichMedia *)richMedia window:(UIWindow *)window richMediaStyle:(PWRichMediaStyle *)style completion:(void(^)(BOOL success))completion;

@end
