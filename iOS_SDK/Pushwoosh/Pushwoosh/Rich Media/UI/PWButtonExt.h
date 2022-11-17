//
//  PWButtonExt.h
//  PushNotificationManager
//
//  Created by User on 24/08/15.
//
//
#if TARGET_OS_IOS || TARGET_OS_WATCH

#import <UIKit/UIKit.h>

@interface PWButtonExt : UIButton

@property (nonatomic, assign) UIEdgeInsets hitTestEdgeInsets;

@end

#endif
