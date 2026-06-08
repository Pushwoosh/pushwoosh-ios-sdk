//
//  PWUtils.h
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWUtils.common.h>

@interface PWUtils : PWUtilsCommon

+ (UIButton *)webViewCloseButton;

+ (BOOL)handleURL:(NSURL *)url;

+ (NSNumber *)startBackgroundTask;
+ (void)stopBackgroundTask:(NSNumber *)taskId;

@end
