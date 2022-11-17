//
//  PWUtils.h
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PWUtilsMobile.h"

@interface PWUtils : PWUtilsMobile

+ (UIButton *)webViewCloseButton;

+ (BOOL)handleURL:(NSURL *)url;

@end
